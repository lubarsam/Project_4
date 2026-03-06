import random
import serial
import serial.tools.list_ports
import threading
import time

#  Serial / UART configuration
BAUD_RATE    = 115200
SERIAL_PORT  = "COM3"

LCD_WIDTH    = 16       # visible characters on the LCD at once
SCROLL_DELAY = 0.35     # seconds between scroll steps (adjust for comfortable reading)

def find_serial_port():
    ports = serial.tools.list_ports.comports()
    for p in ports:
        if "USB" in p.description or "UART" in p.description or "Serial" in p.description:
            return p.device
    return ports[0].device if ports else None

def open_serial(port: str | None = None):
    target = port or SERIAL_PORT or find_serial_port()
    if not target:
        print("[SERIAL] No serial port found – running without FPGA hardware.")
        return None
    try:
        ser = serial.Serial(target, BAUD_RATE, timeout=0.05)
        print(f"[SERIAL] Connected to {target} @ {BAUD_RATE} baud")
        return ser
    except serial.SerialException as e:
        print(f"[SERIAL] Could not open {target}: {e}")
        print("[SERIAL] Running without FPGA hardware.")
        return None

#  UART send helpers
def send_lcd(ser: serial.Serial | None, text: str):
    if ser and ser.is_open:
        frame = f"LCD:{text[:LCD_WIDTH]:<{LCD_WIDTH}}\n"
        ser.write(frame.encode("ascii"))

def send_seg(ser: serial.Serial | None, value: int):
    if ser and ser.is_open:
        frame = f"SEG:{max(0, min(9, value))}\n"
        ser.write(frame.encode("ascii"))

def scroll_lcd(ser: serial.Serial | None, message: str):
    padded = (" " * LCD_WIDTH) + message + (" " * LCD_WIDTH)
    for i in range(len(padded) - LCD_WIDTH + 1):
        window = padded[i:i + LCD_WIDTH]
        send_lcd(ser, window)
        time.sleep(SCROLL_DELAY)

#  PS/2 keyboard reader
_ps2_buffer: list[str] = []
_ps2_lock   = threading.Lock()
_stop_event = threading.Event()

def _ps2_reader_thread(ser: serial.Serial):
    leftover = ""
    while not _stop_event.is_set():
        try:
            raw = ser.read(ser.in_waiting or 1)
            if not raw:
                continue
            leftover += raw.decode("ascii", errors="ignore")
            while "\n" in leftover:
                line, leftover = leftover.split("\n", 1)
                line = line.strip()
                if line.startswith("KEY:") and len(line) == 5:
                    char = line[4].lower()
                    if char.isalpha():
                        with _ps2_lock:
                            _ps2_buffer.append(char)
        except Exception:
            time.sleep(0.01)

def start_ps2_thread(ser: serial.Serial | None):
    if ser is None:
        return None
    t = threading.Thread(target=_ps2_reader_thread, args=(ser,), daemon=True)
    t.start()
    return t

def poll_ps2():
    with _ps2_lock:
        return _ps2_buffer.pop(0) if _ps2_buffer else None

def clear_ps2_buffer():
    with _ps2_lock:
        _ps2_buffer.clear()

#  Input helpers
def get_guess(already_guessed: list[str]):
    while True:
        ps2 = poll_ps2()
        if ps2:
            if ps2 in already_guessed:
                print(f"[PS/2] '{ps2}' already guessed – press another key.")
                continue
            print(f"[PS/2] Received: {ps2}")
            return ps2

        print("Guess a letter (PC keyboard or PS/2): ", end="", flush=True)

        kb_result: list[str] = []
        def _kb_input():
            try:
                kb_result.append(input())
            except EOFError:
                pass

        kb_thread = threading.Thread(target=_kb_input, daemon=True)
        kb_thread.start()

        while kb_thread.is_alive():
            ps2 = poll_ps2()
            if ps2:
                print()
                if ps2 not in already_guessed:
                    return ps2
                else:
                    print(f"[PS/2] '{ps2}' already guessed.")
                    break
            time.sleep(0.05)

        if kb_result:
            guess = kb_result[0].strip().lower()
            if len(guess) == 1 and guess.isalpha():
                if guess in already_guessed:
                    print(f"'{guess}' already guessed – try again.")
                    continue
                return guess
            else:
                print("Please enter a single letter.")

def get_yn(prompt: str):
    while True:
        ps2 = poll_ps2()
        if ps2 in ("y", "n"):
            print(f"[PS/2] Received: {ps2}")
            return ps2

        print(prompt, end="", flush=True)

        kb_result: list[str] = []
        def _kb_input():
            try:
                kb_result.append(input())
            except EOFError:
                pass

        kb_thread = threading.Thread(target=_kb_input, daemon=True)
        kb_thread.start()

        while kb_thread.is_alive():
            ps2 = poll_ps2()
            if ps2 in ("y", "n"):
                print()
                return ps2
            time.sleep(0.05)

        if kb_result:
            ans = kb_result[0].strip().lower()
            if ans in ("y", "n"):
                return ans
            else:
                print("Please type Y or N.")

#  FPGA update helper
def update_fpga(ser, display: list[str], lives: int):
    send_lcd(ser, " ".join(display))
    send_seg(ser, lives)

#  Single round of hangman
#  Returns True if the word was guessed, False if the player lost.
def play_round(ser, chosen_word: str, stages, gameover_art, win_art):
    word_len      = len(chosen_word)
    lives         = 6
    display       = ["_"] * word_len
    guessed       : list[str] = []
    wrong_guesses : list[str] = []

    update_fpga(ser, display, lives)

    while True:
        print(f"\nLives remaining: {lives}")
        print(f"Word: {' '.join(display)}")
        if wrong_guesses:
            print(f"Wrong guesses: {' '.join(wrong_guesses).upper()}")

        guess = get_guess(guessed)
        guessed.append(guess)

        correct = False
        for i, letter in enumerate(chosen_word):
            if letter == guess:
                display[i] = letter
                correct = True

        if not correct:
            lives -= 1
            wrong_guesses.append(guess)
            print(f"'{guess}' is not in the word. You lose a life.")

        update_fpga(ser, display, lives)
        print(f"\n{' '.join(display)}")
        print(stages[lives])

        if lives == 0:
            print(gameover_art)
            return False

        if "_" not in display:
            print(win_art)
            return True

#  Main game loop
def main():
    from hangman_words import word_list
    from hangman_art   import logo, welcome, gameover, win, stages

    ser = open_serial()
    start_ps2_thread(ser)

    print(welcome)
    print(logo)

    # Shuffle a copy so words are never repeated and can detect exhaustion
    remaining_words = word_list[:]
    random.shuffle(remaining_words)

    puzzles_total  = 0   # M – total puzzles played
    puzzles_solved = 0   # N – puzzles successfully solved

    while remaining_words:
        chosen_word   = remaining_words.pop()
        puzzles_total += 1

        won = play_round(ser, chosen_word, stages, gameover, win)

        if won:
            puzzles_solved += 1
            msg = (f"Well done! You have solved {puzzles_solved} "
                   f"puzzles out of {puzzles_total}")
            print(f"\n{msg}")
            scroll_lcd(ser, msg)
        else:
            msg = (f"Sorry! The correct word was {chosen_word.upper()}. "
                   f"You have solved {puzzles_solved} puzzles out of {puzzles_total}.")
            print(f"\n{msg}")
            scroll_lcd(ser, msg)

        # Offer a new game if words remain
        if remaining_words:
            send_lcd(ser, "New Game?       ")
            clear_ps2_buffer()
            answer = get_yn("New Game? (Y/N): ")
            if answer == "n":
                break
        else:
            print("\nAll words have been used!")

    # Final message
    print("\nGAME OVER.")
    print(f"Final score: {puzzles_solved} solved out of {puzzles_total} played.")
    send_lcd(ser, "GAME OVER.      ")
    send_seg(ser, 0)

    _stop_event.set()
    if ser and ser.is_open:
        ser.close()

if __name__ == "__main__":
    main()
