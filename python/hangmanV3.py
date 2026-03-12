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
chosen_word = random.choice(word_list)
def play_round(ser, chosen_word: str, stages):
    word_length = len(chosen_word)
    lives = 6
    display = ["_"] * word_length
    guessed : list[str] = []
    guessed_wrong : list[str] = []
    
    while not end_of_game:
        print(f"\nLives remaining: {lives}")
        disp(" ".join(display), "".join(guessed_wrong), lives, ser)
        guess = ps2in("Guess a letter: ", ser).lower()

        if not guess.isalpha():
            continue

        if guess in display of guess in guessed_wrong:
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

        print(f"{' '.join(display))")
        print(stages[lives])

        if lives == 0:
            end_of_game = True
            print("you lose")
            disp("Game Over", f"Word: {chosen_word}", 0, ser)
            return False
        elif "_" not in display:
            end_of_game = True
            print("You win")
            disp("You win", " ".join(display), lives, ser)
            return True
        
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

        won = play_round(ser,  chosen_wrd, stages)

        if won:
            puzzles_solved += 1
            print(f"You have solved {puzzles_solved} out of {puzzles_total}")

        else:
            print(f"The correct word was {chosen_word}.  solved {puzzles_solved} out of {puzzles_total}")

        if remaining_word:
            disp("New Game?", "                ", 0, ser)
            answer = ps2in("New Game? [y/n]: ", ser)

            if answer == "n":
                ser.close()
                break
        else:
            print("\nAll words have been used")
            ser.close()

    print("\nGAMEOVER.")
    print(f"Final score: {puzzles_solved} solved out of {puzzles_total} played.")

if __name__ == "__main__":
    main()
