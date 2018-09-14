import sys
sys.path.insert(0, '../angelos')

from angelos.document.entity import Person, Ministry, Church  # noqa E402


p = Person({})
m = Ministry({})
c = Church({})

print(p.yaml())
print(m.yaml())
print(c.yaml())
