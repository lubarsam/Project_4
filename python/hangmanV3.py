import serial
import random

# Serial setup
ser = serial.Serial('COM4', baudrate=115200, timeout=0.1)

def ps2in(prompt, ser):
    print(prompt)
    while True:
        char = ser.read(1)
        if char:
            return char.decode(errors="ignore")

def disp(lcd_line1, lcd_line2, lives, ser):
    # LCD: send exactly 32 chars (16 per line)
    line1 = lcd_line1[:16].ljust(16)
    line2 = lcd_line2[:16].ljust(16)
    ser.write(("LCD:" + line1 + line2 + "\n").encode('utf-8'))
    # Seven segment: send lives (single digit)
    ser.write(("SEG:" + str(lives) + "\n").encode('utf-8'))

# Single round
def play_round(ser, chosen_word: str, stages):
    word_length = len(chosen_word)
    lives = 6
    display = ["_"] * word_length
    guessed: list[str] = []
    guessed_wrong: list[str] = []
    end_of_game = False      

    while not end_of_game:
        print(f"\nLives remaining: {lives}")
        if guessed_wrong:
            print(f"Wrong guesses: {' '.join(guessed_wrong).upper()}")
        disp(" ".join(display), "".join(guessed_wrong), lives, ser)
        guess = ps2in("Guess a letter: ", ser).lower()
        if not guess.isalpha():
            continue
        if guess in display or guess in guessed_wrong:
            print(f"You've already guessed {guess}")
            continue
        if guess in chosen_word:
            for position in range(word_length):
                if chosen_word[position] == guess:
                    display[position] = guess
        else:
            lives -= 1
            guessed_wrong.append(guess)
            print(f"You guessed {guess}, that's not in the word. You lose a life.")
        word_str = " ".join(display)
        wrong_str = "".join(guessed_wrong)
        disp(word_str, wrong_str, lives, ser)
        print(f"{' '.join(display)}")
        print(stages[lives])
        if lives == 0:
            end_of_game = True
            print("You lose")
            disp("Game Over", f"Word: {chosen_word}", 0, ser)
            return False
        elif "_" not in display:
            end_of_game = True
            print("You win!")
            disp("You win!", " ".join(display), lives, ser)
            return True
# main loop
def main():
    from hangman_words import word_list
    from hangman_art import logo, welcome, stages

    ser.close()
    ser.open()
    print(welcome)
    print(logo)

    remaining_words = word_list[:]
    random.shuffle(remaining_words)
    puzzles_total = 0
    puzzles_solved = 0

    while remaining_words:
        chosen_word = remaining_words.pop()
        puzzles_total += 1
        won = play_round(ser, chosen_word, stages)
        if won:
            puzzles_solved += 1
            print(f"You have solved {puzzles_solved} out of {puzzles_total}")
        else:
            print(f"The correct word was {chosen_word}. Solved {puzzles_solved} out of {puzzles_total}")
        if remaining_words:   
            disp("New Game?", "                ", 0, ser)
            answer = ps2in("New Game? [y/n]: ", ser)
            if answer == "n":
                ser.close()
                break
        else:
            print("\nAll words have been used")
            ser.close()

    print("\nGAME OVER.")
    print(f"Final score: {puzzles_solved} solved out of {puzzles_total} played.")

if __name__ == "__main__":
    main()

