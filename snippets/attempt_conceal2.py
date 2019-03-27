import sys
sys.path.append('../angelos')  # noqa

import io
import os
import fcntl
import math
import base64
import struct
import array

import libnacl.secret

from angelos.utils import Util
from angelos.error import Error

LIPSUM = b"""
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam posuere felis id magna vulputate malesuada. Morbi faucibus nibh ipsum, sit amet tincidunt nunc scelerisque in. In tortor risus, ultrices in nulla ut, malesuada congue urna. Integer dignissim tortor est, vitae porta orci tincidunt ac. Donec placerat sem et odio volutpat tristique. Maecenas malesuada pretium massa et viverra. In elementum porta libero, sit amet suscipit ipsum hendrerit pharetra. Vivamus tempor odio at pulvinar accumsan. Morbi quis posuere leo. Proin accumsan venenatis auctor. Etiam iaculis neque vitae libero eleifend sollicitudin. Duis eu quam ligula. Suspendisse convallis augue sed odio consectetur feugiat. Nam feugiat volutpat tortor, eu ultrices felis lobortis ac.
Fusce vel elit est. Etiam tristique enim eu lacus convallis, quis pharetra ipsum pharetra. Suspendisse vulputate tortor at mattis lobortis. Praesent id ipsum vel ipsum pellentesque euismod. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Vestibulum nec ligula nisl. Donec tristique, neque at pulvinar dignissim, nibh dui tristique dolor, nec varius ipsum metus sed arcu. Morbi ornare varius arcu, at condimentum magna molestie in. Nulla ac sem urna. Nunc ullamcorper ipsum felis, quis dictum odio fermentum a. Phasellus ac fringilla magna.
Duis tortor velit, ultrices eu ex quis, laoreet vulputate elit. Nam non sodales dui. Proin rhoncus sed erat in congue. In hac habitasse platea dictumst. Vivamus quis nibh orci. Phasellus aliquam in tellus eu semper. Quisque in rhoncus orci, at placerat velit. Nunc eu neque tempus, interdum nibh eu, mollis lectus. Nam lacus felis, vehicula a mauris et, mattis gravida nulla. Vestibulum faucibus ligula nec molestie accumsan. Nunc et lacus dolor. Etiam quis libero eget tellus dapibus ullamcorper. Ut quis felis ut dolor maximus ultrices nec eget sapien. Proin eget odio faucibus, aliquet justo ac, dignissim ipsum. Nulla laoreet laoreet rhoncus. Integer elementum magna et turpis eleifend, vel gravida mi dictum.
Mauris vel urna volutpat nulla pharetra dapibus vitae vel enim. Nullam at eros eu ipsum eleifend bibendum. Aliquam ac dictum tellus. Curabitur vel ante neque. In porttitor leo et molestie finibus. Proin euismod sagittis lacus, id vehicula leo porttitor nec. Ut ultrices sit amet tortor a condimentum. Vivamus imperdiet eleifend erat in condimentum. Aliquam enim felis, facilisis at ullamcorper a, tristique at ex. Aliquam et maximus enim. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Proin et est tortor. Sed vestibulum nisl nec lacus dapibus, a ultrices elit lobortis.
Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. In efficitur lorem in nibh dignissim, in feugiat leo porta. Vivamus imperdiet, urna et tincidunt aliquam, augue risus dapibus justo, eu consectetur nisl enim ut metus. Curabitur diam dolor, suscipit vitae scelerisque id, pretium ut libero. Maecenas congue, ligula eget facilisis pretium, ligula dui posuere nulla, eget tincidunt nisl nisl eu elit. Nam vehicula porta nisl in pharetra. Donec fermentum, massa id auctor condimentum, nunc risus viverra sapien, ut pellentesque odio nisl non metus. Donec hendrerit diam quis rutrum ultricies. Donec lobortis, libero ac ullamcorper feugiat, odio risus feugiat nulla, non scelerisque neque justo a dolor. Pellentesque tincidunt venenatis metus ac viverra. Phasellus in nibh quis lectus ultrices rhoncus eget suscipit erat. Donec vitae massa congue, posuere quam in, fermentum arcu. Morbi tempor sem nisl, at tincidunt enim luctus id. Fusce et cursus ex.
Pellentesque ut velit ut nibh rhoncus mattis sit amet rhoncus justo. Proin laoreet libero eget arcu imperdiet, eget tristique dui tempor. Ut quis libero libero. Nam non vulputate sapien. Maecenas eu odio vel libero sodales iaculis. Aenean eleifend, est eget mattis auctor, diam enim dictum libero, sed ornare nisl tortor nec ipsum. Aliquam vehicula magna nulla, ut dapibus sem ornare eget. Ut ligula tellus, dapibus at venenatis vitae, scelerisque vitae eros. Vestibulum in elementum orci. Ut ut sollicitudin eros. Maecenas ac ligula blandit, posuere ante sit amet, dapibus est. Pellentesque enim dolor, finibus pretium aliquet nec, egestas id justo. Nunc a ipsum eu lorem consectetur mattis vitae ut turpis. In efficitur, eros sit amet pharetra sodales, quam justo tempus ipsum, ut pulvinar nunc metus in leo. Nulla neque ligula, cursus ac risus et, rhoncus pellentesque orci. Sed sed gravida nisl, ut tincidunt lectus.
Phasellus pellentesque dolor viverra auctor interdum. Aliquam eu tristique odio. Quisque placerat tellus ac leo pellentesque euismod. Aenean semper placerat posuere. Cras pretium vitae enim a volutpat. Curabitur vulputate felis eu urna feugiat, vitae porttitor orci condimentum. In vel dolor porttitor, fringilla ipsum sed, ornare turpis. Suspendisse interdum, diam sed tincidunt maximus, neque felis tempor felis, cursus aliquam urna orci sit amet neque. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Fusce interdum vehicula justo scelerisque maximus. Suspendisse in massa consectetur ligula tempor cursus convallis vitae eros. Aliquam condimentum at arcu eget ullamcorper. Aliquam hendrerit ante ut eleifend fermentum. Praesent cursus rhoncus diam ut lacinia.
Aliquam feugiat finibus posuere. Proin eget justo finibus, laoreet ligula non, blandit ligula. Nam facilisis lobortis felis ut semper. Sed sed nunc ut eros ornare sagittis. Cras lobortis, arcu eget feugiat tincidunt, erat leo malesuada erat, vitae malesuada odio magna ut est. Integer tortor libero, posuere non mattis at, cursus sed ipsum. Donec euismod malesuada massa, a iaculis augue vulputate sed. Sed vehicula sodales imperdiet. Proin porta augue arcu, quis tempor augue dapibus et. Nam sit amet magna vel ligula pharetra lobortis quis eu tellus.
Aliquam tempor ligula sapien, at pellentesque tellus posuere vel. Sed sed elit eu lorem placerat imperdiet. Integer non tempus nisl. Phasellus sollicitudin fringilla consectetur. Maecenas id nunc ut quam mollis venenatis. Ut et lectus eget ipsum iaculis convallis laoreet ut magna. Ut quis elit non nisl sagittis cursus vitae vitae dui. Aenean ac purus ut eros semper faucibus. Quisque cursus dapibus eros id lobortis. Nam ut auctor tortor. Aliquam in aliquam enim, in auctor est. Nulla facilisi. Morbi vel pretium magna, vitae suscipit magna. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Pellentesque sagittis non nisi sit amet rutrum. Cras lorem justo, gravida et faucibus vel, faucibus at ex.
Donec tincidunt tincidunt aliquam. Cras ullamcorper sed massa sed sollicitudin. Duis at risus sed sem molestie dictum in quis libero. Suspendisse efficitur lobortis scelerisque. Donec sodales tristique lacus, quis malesuada nunc vestibulum a. Curabitur ante arcu, blandit nec fringilla ac, viverra id turpis. Nulla pellentesque enim ante, non auctor dui ornare at. Nunc iaculis dolor egestas velit facilisis blandit.
Maecenas id tempor nulla. Mauris sapien velit, bibendum vel ex vitae, accumsan maximus velit. Aliquam orci orci, viverra a leo eu, gravida posuere tortor. Phasellus vel magna eleifend, sagittis quam at, posuere massa. Vestibulum sit amet ex mi. Sed ultrices arcu non dui gravida, ut laoreet risus vehicula. Cras id lectus consectetur, dictum eros a, sodales turpis. Morbi maximus aliquet convallis. Morbi eleifend mattis nibh et pharetra. Proin diam nunc, bibendum sed purus tristique, placerat dictum tortor. Curabitur mattis ex a tortor iaculis, at efficitur ex sagittis. Ut sit amet aliquet dolor, eget consectetur augue. Sed in nunc et enim tempor ullamcorper non ut mi. Donec id massa eu sem tincidunt pulvinar et eget orci.
Nullam laoreet justo finibus, ullamcorper magna sed, aliquam felis. Suspendisse fermentum molestie nisl, et ultricies ante pharetra vitae. Curabitur sit amet facilisis ligula. Ut ultrices vehicula massa. Maecenas nulla ex, vestibulum et dui et, commodo iaculis ipsum. Vivamus non cursus massa, tincidunt semper magna. Aliquam vitae nunc ex. Maecenas sem lectus, ultricies quis diam vitae, rhoncus luctus ante. Nullam non volutpat mauris. Nam porttitor eget ante quis dignissim. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.
Ut sed tortor arcu. Morbi eu molestie nulla. Sed mi nisl, iaculis nec imperdiet condimentum, viverra ut tellus. Proin risus mi, egestas vitae tempus ut, eleifend in velit. In tempus, ante eu feugiat blandit, diam orci maximus felis, ut malesuada erat risus commodo mi. Curabitur viverra sollicitudin dui non vulputate. Phasellus non enim cursus, accumsan odio a, eleifend est. Interdum et malesuada fames ac ante ipsum primis in faucibus. Interdum et malesuada fames ac ante ipsum primis in faucibus. Aliquam ornare, nunc a semper pretium, arcu augue imperdiet turpis, a egestas nunc massa eu risus. Nullam pulvinar imperdiet lorem, eget placerat tellus facilisis eget. Phasellus felis odio, pulvinar eget lorem vel, consequat luctus augue. Nullam accumsan interdum felis, nec malesuada dui aliquet sit amet. Proin nec suscipit ligula. Proin sollicitudin lacus vel facilisis dignissim. Aliquam nec dui a orci bibendum ultrices sit amet id mi.
Suspendisse sodales euismod elit blandit venenatis. Aenean porta quis justo sed tempor. In venenatis odio vel justo hendrerit ultrices. Aliquam erat volutpat. Nullam vitae velit lacinia, faucibus risus mollis, faucibus velit. Aenean sollicitudin enim diam, nec interdum nunc blandit quis. Ut pellentesque lacus ipsum, eget mattis ligula ultricies sed.
Proin varius, leo a porta egestas, dolor nisi commodo est, vitae imperdiet purus sem at massa. Donec ac porttitor turpis, sed congue lectus. Morbi aliquam placerat aliquet. Quisque egestas quam augue, vitae luctus turpis lobortis sit amet. Suspendisse a lectus eget tellus ullamcorper commodo at id eros. Vestibulum sed sapien nec libero porttitor malesuada. Pellentesque eget volutpat ante, at convallis dolor. Sed rutrum nunc mi, ullamcorper feugiat odio aliquet quis. Ut vitae dolor mauris. Pellentesque sit amet lorem at ligula scelerisque feugiat. Etiam commodo magna in maximus semper. Morbi quis dolor vitae mauris convallis rutrum nec eu dui.
Duis tincidunt eros eget tellus mattis, eu pretium elit condimentum. Duis accumsan tellus a auctor scelerisque. Nunc malesuada tincidunt urna, sed fringilla urna ullamcorper ac. Praesent eu augue nec purus tincidunt dignissim eu non purus. Vestibulum blandit elit et ante aliquam, vel ultricies neque pretium. Aenean vehicula ex vitae malesuada placerat. Vestibulum aliquam dolor neque, non tempor lectus tempus non. In et nulla lorem. Suspendisse pharetra semper lorem et posuere. Sed accumsan dictum orci id commodo. Proin convallis, sem vitae ultricies gravida, sapien dui lacinia quam, id rhoncus enim nibh quis lectus. Donec urna metus, accumsan sit amet ante ac, iaculis porttitor tellus. Donec rutrum sodales felis, ut placerat leo condimentum ac. Phasellus convallis purus quis hendrerit accumsan. Aliquam interdum ullamcorper nibh vitae facilisis. Donec ut suscipit est, ac bibendum felis.
Sed faucibus at sem faucibus scelerisque. Cras nunc ipsum, dapibus viverra velit ac, rutrum vehicula nibh. Integer consequat mattis euismod. Suspendisse sed magna volutpat, auctor nisl a, faucibus arcu. Cras ac arcu eu ipsum maximus aliquet. Duis mattis lorem dui, a laoreet sapien luctus non. Donec lobortis nec magna nec ornare. Curabitur consectetur orci lobortis ligula lacinia, ut egestas ligula fermentum. Ut scelerisque metus vitae condimentum maximus. Nunc et lectus eget mi lacinia consequat non ac ligula. Integer fermentum dui vitae dolor gravida, nec porta purus semper. Aliquam vitae risus pulvinar, facilisis neque eu, lacinia nulla. Aenean imperdiet odio sit amet augue vehicula, eget ultricies orci tristique. In placerat congue urna sed condimentum. Nam dapibus et risus eget iaculis.
Proin congue metus vitae cursus sollicitudin. Suspendisse auctor id velit non finibus. Vestibulum non aliquet eros. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur posuere sed sem quis convallis. Morbi a neque magna. Vivamus fringilla bibendum odio, at fermentum odio molestie ac. Vestibulum a augue scelerisque, elementum lacus eget, gravida diam. In hac habitasse platea dictumst. Etiam at eros accumsan, consectetur ligula quis, tincidunt nisi. Sed id odio dignissim, hendrerit lacus sit amet, iaculis elit.
Donec id tortor ut dolor suscipit ullamcorper id et mauris. Ut vulputate consectetur sagittis. Morbi vehicula dui ac vehicula lacinia. Praesent ultrices fringilla orci eget aliquam. Mauris vel pellentesque nisl. Phasellus euismod nulla nulla. Donec fringilla quam urna, sed mattis leo tincidunt at. Donec varius blandit scelerisque. Mauris commodo dolor mi, id tristique magna fermentum consequat. Nam et nisl at magna porttitor lobortis. Integer efficitur aliquam ligula, nec mollis leo ornare ut. Fusce placerat rhoncus massa sed sodales. Proin mattis diam at nunc consequat volutpat. Suspendisse sodales risus at augue interdum, quis pretium enim lacinia. Sed condimentum dui congue efficitur gravida. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae;
Proin euismod malesuada urna. Quisque leo justo, sollicitudin sodales nibh id, semper vestibulum ligula. In cursus suscipit sem vel malesuada. Pellentesque lacinia nisi rutrum magna porta auctor. Etiam auctor condimentum est quis feugiat. Duis rhoncus tincidunt nulla. Vestibulum pretium nulla non lacinia mattis. Donec consectetur vitae leo nec tristique. Nullam in tincidunt nibh. Vestibulum hendrerit lobortis consectetur. Etiam lorem odio, tristique id nisi ac, suscipit tristique dui. Vivamus nulla ex, cursus vitae mattis vitae, fringilla et nulla. Donec facilisis, nibh sit amet interdum dignissim, ligula tortor congue dui, ut tincidunt lectus enim vitae libero. Nunc ultricies enim elit, et efficitur orci sollicitudin ut. Nulla sit amet leo at justo blandit facilisis.
In hac habitasse platea dictumst. Nunc velit eros, convallis id sollicitudin at, suscipit et eros. Praesent et neque ut enim aliquet aliquet. Aliquam tempor mi leo, vel lacinia est tristique quis. Nam sodales augue id posuere rutrum. Aliquam congue eleifend lectus in mattis. Quisque quis sapien ut lorem tincidunt congue quis eget nibh. Vivamus euismod, leo bibendum congue commodo, mi magna lobortis nisl, non laoreet lacus turpis et lorem. Ut at ultricies erat. Morbi accumsan ligula ut eleifend commodo. Nullam varius turpis et diam gravida ullamcorper. Nulla mollis, neque quis posuere molestie, leo ante vehicula sem, vel varius justo justo a lectus. Phasellus eleifend lacus tincidunt, lobortis mi eu, egestas felis. Nullam mattis tortor risus, a tincidunt ex porta ac.
Praesent fringilla erat eget nunc euismod, ut luctus massa mollis. Aliquam erat volutpat. Pellentesque in laoreet est. Aenean pulvinar urna nisl, finibus venenatis nisi pellentesque a. Duis gravida lorem tempor nulla efficitur, vitae tempor lectus feugiat. Ut in ipsum id velit iaculis tincidunt in scelerisque nibh. Sed in nunc quis quam rhoncus tincidunt vel ut dolor. Morbi ullamcorper ultricies laoreet. Pellentesque sed lobortis enim. Duis mollis sollicitudin felis id posuere. Aliquam accumsan aliquam quam, et hendrerit diam eleifend aliquam. Suspendisse tempus ipsum ex, vitae facilisis odio consectetur at. Vivamus vitae lacus sit amet risus blandit scelerisque. Donec leo neque, placerat maximus ligula quis, feugiat elementum nisl.
Morbi sit amet lorem massa. Praesent et nibh vitae risus gravida scelerisque vitae quis erat. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Ut tortor ligula, dignissim ac rutrum eget, rutrum nec metus. Pellentesque blandit sed nisl a semper. Nam nec consectetur leo. Donec ex ligula, fermentum eu molestie in, pharetra et sem. Sed pharetra elementum ipsum, vitae pharetra justo pretium volutpat. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
Aenean vitae volutpat lectus. Morbi iaculis finibus quam at sodales. Interdum et malesuada fames ac ante ipsum primis in faucibus. Proin placerat metus vel lectus aliquam dictum. Duis sit amet diam at mauris tempus molestie vitae eu lectus. Quisque molestie ex vitae lobortis bibendum. In hac habitasse platea dictumst. In ultricies venenatis purus, ac tempus nisl convallis ac. Praesent ac porttitor arcu.
Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus eget odio scelerisque, commodo urna nec, viverra felis. Donec a mollis quam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nunc rhoncus turpis hendrerit purus posuere semper. Nullam non risus mauris. Etiam vehicula aliquam tempus. Aliquam erat volutpat. Maecenas vehicula vel odio nec dapibus. Nam eu turpis sit amet diam tempor egestas. Aliquam sit amet nisi et enim dictum finibus non eget sem. Duis sed elit lacus.
Cras eu massa efficitur felis fermentum pretium sit amet sit amet ipsum. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Pellentesque vitae vehicula ligula. Aenean condimentum arcu suscipit nisi lacinia, vel dapibus leo volutpat. Interdum et malesuada fames ac ante ipsum primis in faucibus. Curabitur ac velit ipsum. Suspendisse potenti. Nulla tincidunt eu nulla ac maximus. In eget mauris condimentum, ultrices tortor quis, molestie est. Pellentesque consequat fermentum tellus, id eleifend ligula convallis tempus. Donec at libero ac justo porttitor suscipit vitae in velit.
Cras rutrum purus sed nunc commodo blandit. Sed in commodo arcu. Curabitur at ligula ipsum. Aenean cursus nibh non magna commodo commodo. Aliquam interdum nisl nisi, eget iaculis purus volutpat ut. Sed lacinia, diam at tincidunt mollis, mi erat hendrerit neque, interdum faucibus est sapien a eros. Sed varius mi eu sem semper, vitae gravida purus ullamcorper. Donec consectetur hendrerit posuere. Curabitur finibus pretium ligula id dignissim. Quisque non mollis velit. Phasellus convallis congue venenatis. Ut sollicitudin erat eget velit sodales malesuada. Nunc convallis quam leo, id suscipit enim vulputate quis. Quisque eu erat posuere, ultrices nulla vel, mattis sem. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Maecenas dapibus, quam et interdum varius, lorem lacus efficitur sem, in porta est elit in erat.
Suspendisse est magna, tempor vitae luctus ac, tincidunt vitae est. Donec non blandit urna. Quisque ut vestibulum tellus. Nunc sollicitudin vitae tellus non tristique. Maecenas a faucibus libero. Pellentesque dictum tincidunt facilisis. Mauris quis libero justo. Maecenas viverra nisi in nulla ultricies vulputate. Integer mattis semper libero, in suscipit lacus consectetur in. Duis consequat dapibus nibh condimentum tincidunt. Aenean maximus pulvinar lacus, ut eleifend ligula pharetra non. Duis sodales leo eget magna vestibulum malesuada. Aenean faucibus sagittis magna, eget dignissim ligula rutrum ut. Nulla vel placerat mi.
Nam ipsum massa, semper vitae accumsan suscipit, iaculis eu est. Duis magna purus, dignissim gravida ullamcorper eu, facilisis sit amet mauris. Phasellus maximus luctus aliquet. Vivamus ut orci iaculis quam elementum fermentum eu quis nisi. Aenean nulla enim, imperdiet in sapien dapibus, mattis porttitor tortor. Aenean posuere leo ex. Nunc elementum a enim vitae sodales. Suspendisse nec lacus mauris. Proin ac porta dolor, eu mollis felis. Aliquam vel est finibus, suscipit nulla sed, porttitor augue. Aenean malesuada convallis mauris vehicula sagittis. Praesent finibus sapien arcu.
Phasellus condimentum quis sapien pulvinar condimentum. Suspendisse neque nunc, bibendum et erat ut, porta eleifend orci. Donec a justo eget turpis condimentum auctor et a urna. Fusce scelerisque metus quis magna interdum, vel convallis tellus suscipit. Maecenas aliquet elit sit amet maximus aliquam. Ut aliquet ante eu tortor dictum lobortis. Nullam rutrum elit eget elementum interdum. Fusce dapibus quam ac turpis suscipit tempor. Donec vel libero nec ex dictum malesuada at at metus. Sed sit amet hendrerit justo, vitae ornare sem. Nam egestas at arcu vel lobortis. Duis sed nulla libero. Curabitur mi lacus, commodo quis leo vitae, lobortis mattis amet.
"""  # noqa E501


class ConcealIO(io.RawIOBase):
    TOT_SIZE = 512*33
    CBLK_SIZE = 512*32 + 40
    ABLK_SIZE = 512*32

    def __init__(self, file, mode='rb', secret=None):
        Util.is_type(file, (str, bytes, io.IOBase))
        Util.is_type(mode, (str, bytes))
        Util.is_type(secret, (str, bytes))

        if isinstance(file, io.IOBase):
            if file.mode not in ['rb', 'rb+', 'wb', 'ab']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self.__path = file.name
            self.__mode = file.mode
            self.__file = file
            self.__do_close = False
        else:
            if mode not in ['rb', 'rb+', 'wb', 'ab']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self.__path = file
            self.__mode = mode
            self.__file = open(file, mode)
            self.__do_close = True

        fcntl.flock(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

        self.__box = libnacl.secret.SecretBox(secret)
        self.__block_cnt = int(os.fstat(
            self.__file.fileno()).st_size / ConcealIO.TOT_SIZE)
        self.__len = 0 if self.__block_cnt == 0 else self.__length()
        self.__size = self.__block_cnt * ConcealIO.ABLK_SIZE
        self.__block_idx = 0
        self.__cursor = 0
        self.__blk_cursor = 0
        self.__save = False
        self.__buffer = None

        if self.__block_cnt:
            self._load(0)
        else:
            self.__buffer = bytearray().ljust(ConcealIO.ABLK_SIZE, b'\x00')

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __length(self, offset=None):
        Util.is_type(offset, (int, type(None)))

        realpos = self.__file.tell()
        self.__file.seek(ConcealIO.CBLK_SIZE)

        if offset is None:
            data = self.__box.decrypt(self.__file.read(48))
            offset = struct.unpack('!Q', data)[0]
        elif self.__mode in ['rb+', 'wb']:
            data = bytearray(self.__box.encrypt(
                struct.pack('!Q', offset)) + os.urandom(424))
            self.__file.write(data)

        self.__file.seek(realpos)
        return offset

    def _load(self, blk):
        pos = blk * ConcealIO.TOT_SIZE
        res = self.__file.seek(pos)
        print('Load block:', blk)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self.__block_cnt > blk:
            self.__buffer = bytearray(self.__box.decrypt(
                self.__file.read(ConcealIO.CBLK_SIZE)))
        else:
            self.__buffer = bytearray().ljust(ConcealIO.ABLK_SIZE, b'\x00')

        self.__block_idx = blk
        self.__save = False
        return True

    def _save(self):
        if not self.__save:
            return False

        pos = self.__block_idx * ConcealIO.TOT_SIZE
        print('Save block:', self.__block_idx)
        res = self.__file.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self.__block_idx is 0:
            filler = b''
        else:
            filler = os.urandom(472)
        block = bytearray(
            self.__box.encrypt(self.__buffer) + filler)
        self.__file.write(block)

        if self.__block_idx >= self.__block_cnt:
            self.__blk_cnt = self.__block_idx + 1
            self.__size = self.__block_cnt * ConcealIO.TOT_SIZE

        self.__save = False
        return True

    def close(self):
        if not self.closed:
            self.__length(self.__len)
            fcntl.flock(self.__file, fcntl.LOCK_UN)
            io.RawIOBase.close(self)
            if self.__do_close:
                self.__file.close()

    def fileno(self):
        return self.__file.fileno()

    def flush(self):
        self._save()
        self.__length(self.__len)
        io.RawIOBase.flush(self)

    def isatty(self):
        if self.closed:
            raise ValueError()
        return False

    def read(self, size=-1):
        if self.closed:
            raise ValueError()

        if isinstance(size, type(None)) or size == -1:
            size = self.__len - self.__cursor
        if size > (self.__len - self.__cursor):
            raise ValueError()

        block = bytearray()
        cursor = 0
        self._save()

        print('Read:', self.__cursor, size)

        while size > cursor:
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, size - cursor)

            block += self.__buffer[self.__blk_cursor:self.__blk_cursor+numcpy]
            print('Buffer read:', self.__cursor, numcpy)
            cursor += numcpy
            self.__cursor += numcpy
            self.__blk_cursor += numcpy

            if self.__blk_cursor == ConcealIO.ABLK_SIZE:
                self._load(self.__block_idx + 1)
                self.__blk_cursor = 0

        return block

    def readable(self):
        if self.closed:
            raise ValueError()
        return True

    def readall(self):
        if self.closed:
            raise ValueError()
        return self.read()

    def readinto(self, b):
        if self.closed:
            raise ValueError()
        Util.is_type(b, (bytearray, memoryview, array.array))
        size = min(len(b), self.__len - self.__cursor)
        if isinstance(b, memoryview):
            b.cast('b')
        # for k, v in enumerate(self.read(size)):
        b[:size] = array.array('', self.read(size)[:size])
        if isinstance(b, memoryview):
            b.cast(b.format)
        return size

    def readline(self, size=-1):
        if self.closed:
            raise ValueError()

    def readlines(self, hint=-1):
        if self.closed:
            raise ValueError()

    def seek(self, offset, whence=io.SEEK_SET):
        if self.closed:
            raise ValueError()
        if whence == io.SEEK_SET:
            cursor = min(max(offset, 0), self.__len)
        elif whence == io.SEEK_CUR:
            if offset < 0:
                cursor = max(self.__cursor + offset, 0)
            else:
                cursor = min(self.__cursor + offset, self.__len)
        elif whence == io.SEEK_END:
            cursor = max(min(self.__len + offset, self.__len), 0)
        else:
            raise Util.exception(Error.CONCEAL_INVALID_SEEK, {
                'whence': whence})

        blk = int(math.floor(cursor / self.ABLK_SIZE))
        if self.__block_idx != blk:
            self._save()
            self._load(blk)

        self.__blk_cursor = cursor - (blk * self.ABLK_SIZE)
        self.__cursor = cursor
        return self.__cursor

    def seekable(self):
        if self.closed:
            raise ValueError()
        return True

    def tell(self):
        if self.closed:
            raise ValueError()
        return self.__cursor

    def truncate(self, size=None):
        if size:
            blk = int(math.floor(size / self.ABLK_SIZE))
            if self.__block_idx != blk:
                self._save()
                self._load(blk)
            blk_cursor = size - (blk * self.ABLK_SIZE)
            self.__len = size
        else:
            blk_cursor = self.__blk_cursor
            self.__len = self.__cursor

        self.__save = True
        space = ConcealIO.ABLK_SIZE - blk_cursor
        self.__buffer[self.__blk_cursor:ConcealIO.ABLK_SIZE] = b'\x00' * space
        self._save()
        self.__block_cnt = self.__block_idx+1

        self.__length(self.__len)
        self.__file.truncate(self.__block_cnt * ConcealIO.TOT_SIZE)

    def writable(self):
        if self.closed:
            raise ValueError()
        return True

    def write(self, b):
        if self.closed:
            raise ValueError()

        Util.is_type(b, (bytes, bytearray, memoryview))

        wrtlen = len(b)
        if not wrtlen:
            return 0

        cursor = 0

        print('Write:', self.__cursor, wrtlen)

        while wrtlen > cursor:
            self.__save = True
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, wrtlen - cursor)

            self.__buffer[self.__blk_cursor:self.__blk_cursor + numcpy] = b[cursor: cursor + numcpy]  # noqa E501
            print('Buffer write:', self.__cursor, numcpy)

            cursor += numcpy
            self.__blk_cursor += numcpy
            self.__cursor += numcpy
            if self.__cursor > self.__len:
                self.__len = self.__cursor
                # self.__length(self.__len)

            if self.__blk_cursor >= ConcealIO.ABLK_SIZE:
                self._save()
                self.__length(self.__len)
                self._load(self.__block_idx + 1)
                self.__blk_cursor = 0

        return cursor if cursor else None

    def writelines(self, lines):
        if self.closed:
            raise ValueError()

        for line in lines:
            if not isinstance(line, bytes):
                raise TypeError()
            self.write(line)

    # def __del__(self):
    #    self.close()

    @property
    def name(self):
        return self.__path

    @property
    def mode(self):
        return self.__mode


file = './test.cnl'
secret = 'jBInDQgVpoVcPcFHipwor9NiTTtefVCLABHlDA44+Sc='

with ConcealIO(file, 'wb', base64.b64decode(secret)) as cnl:
    cnl.write(LIPSUM)

with ConcealIO(file, 'rb+',  base64.b64decode(secret)) as cnl:
    print(cnl.read() == LIPSUM)

try:
    pass
    os.unlink(file)
except FileNotFoundError as e:
    pass
