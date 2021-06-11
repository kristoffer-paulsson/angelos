# Angelos control program

CLI interface to remotely administrate the Angelos server.


## Testing

Tokens used for testing (seed in base64, seed in hex, vk in base64):
1. Server: FOt2X2fuVK7wlYwLve4B45K747Xtu+h3z/XqYbyKKTs= 14EB765F67EE54AEF0958C0BBDEE01E392BBE3B5EDBBE877CFF5EA61BC8A293B EctQh/TIVGKbDunHblpuzZZ1R8b7icE6qQtD2Hb0GGk=
2. Admin: TA3I9mc0gACe4wR+6+JoyUbVOw03ktzBSH5IOtNpc5I= 4C0DC8F6673480009EE3047EEBE268C946D53B0D3792DCC1487E483AD3697392 WSDI1nbgIHd/Zy1WwuHrnxxt/VDqHZCixbJJ7UHdHe8=

Create a folder for testing called ```dev_env``` that will cover all server folders.
Then create ```dev_env/admins.pub``` holding the verifier key of every admin on each row, looking like:
```
WSDI1nbgIHd/Zy1WwuHrnxxt/VDqHZCixbJJ7UHdHe8=
```
Also create the ```dev_env/server``` file with the server seed.
```
FOt2X2fuVK7wlYwLve4B45K747Xtu+h3z/XqYbyKKTs=
```
Create also the ```dev_env/config.json``` and ```dev_env/env.json``` json files, they should both be empty json objects.
```
{}
```
Now you could start the server pointing it to ```./dev_env/```.
> angelos-server/bin/angelos -l=localhost -p=1024 --root-dir=./dev_env/ --run-dir=./dev_env/
> --state-dir=./dev_env/ --logs-dir=./dev_env/ --conf-dir=./dev_env/ &

When the server is up and running you can use the control program to access the server.
> angelos-ctl/bin/angelosctl 127.0.0.1 -p=1024 -s=4C0DC8F6673480009EE3047EEBE268C946D53B0D3792DCC1487E483AD3697392

