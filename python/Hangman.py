#import serial
#ser = serial.Serial(port='COM3', daudrate=115200, xonxoff=True)

import random
from hangman_words import word_list

chosenWord = random.choice(word_list)
wordLen = len(chosenWord)

gameEnd = False
lives = 6

from hangman_art import logo
from hangman_art import welcome
from hangman_art import gameover
from hangman_art import win
print(welcome)
print(logo)


display = []
for _ in range(wordLen):
    display += "_"

while not gameEnd:
    guess = input("Guess a letter: ").lower()

    if guess in display:
        print(f"[guess] already guessed")

    for position in range(wordLen):
        letter = chosenWord[position]
        if letter == guess:
            display[position] = letter

    if guess not in chosenWord:
        lives -= 1
        print(f"{guess} is not in the word.  You lose a life.")
        if lives == 0:
            gameEnd = True
            print(gameover)

    print(f"{' '.join(display)}")

    if "_" not in display:
        gameEnd = True
        print(win)

    from hangman_art import stages
    print(stages[lives])
