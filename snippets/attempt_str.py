import re
import platform
import libnacl.secret
import plyer

text = 'Hello    world !'
print(text)

print(re.sub(' +', ' ', text.strip()).split(' '))

print(list(filter(None, text.strip().split(' '))))

print(platform.platform(), plyer.uniqueid.id)


#
box = libnacl.secret.SecretBox()
key = str(box.hex_sk(), 'utf_8')
if not plyer.keystore.get_key('Λόγῳ', 'conceal'):
    plyer.keystore.set_key('Λόγῳ', 'conceal', key)
key2 = libnacl.encode.hex_decode(plyer.keystore.get_key('Λόγῳ', 'conceal'))
box2 = libnacl.secret.SecretBox(key2)
print(key2)
