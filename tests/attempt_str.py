import re

text = 'Hello    world !'
print(text)

print(re.sub(' +', ' ', text.strip()).split(' '))

print(list(filter(None, text.strip().split(' '))))
