import math


def gamma(t):
    x = []
    y = []
    while(t > 0):
        x.append(t % 2)
        t = int(t / 2)
    for i in range(len(x)-1):
        y.append(0)
    for i in range(len(x)):
        y.append(x.pop())
    return y


def delta(x):
    t = math.floor(1+math.log(x, 2))
    p = gamma(t)
    y = []
    while(x > 0):
        y.append(x % 2)
        x = int(x / 2)
    y.pop()
    for i in range(len(y)):
        p.append(y.pop())
    return ''.join(map(str, p))


def decode(x):
    num = 0
    for i in range(len(x)):
        num += int(x[len(x)-1-i])*(math.pow(2, i))
    return int(num)


def undelta(x):
    if x == '1':
        return x
    else:
        x = list(x)
        t = 0
        v = []
        b = False
        w = []
        c = False
        for i in x:
            if not b:
                if i == '0':
                    t += 1
                else:
                    v.append(i)
                    b = True
            elif not c:
                if t == 0:
                    c = True
                    w.append('1')
                    w.append(i)
                else:
                    v.append(i)
                    t -= 1
            else:
                num = decode(v)
                if num == 0:
                    break
                else:
                    w.append(i)
                    num -= 1
    return decode(w)


for x in range(1, 257):
    y = delta(x)
    print('\'' + y + '\',')
