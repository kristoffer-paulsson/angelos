from fs import open_fs


new_tar = open_fs('tar://clientroot/default.tar', writeable=True, create=True)
new_tar.settext('README', 'Hello world!')
new_tar.mkdir('/person')
new_tar.mkdir('/cache')
print(new_tar.listdir('/'))
new_tar.close()
