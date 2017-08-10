#!/usr/bin/python3
import sys, os, pty
sys.path.append(os.path.join(os.path.dirname(__file__),'../bindings/python/'))
import serverboards, pexpect, shlex, re, subprocess, random, sh
import urllib.parse as urlparse
import base64
import time
from cache_ttl import cache_ttl
from common import *
from serverboards import file, print

td_to_s_multiplier=[
    ("ms", 0.001),
    ("s", 1),
    ("m", 60),
    ("h", 60*60),
    ("d", 24*60*60),
]

def try_or(fn, _else):
  try:
    fn()
  except:
    return _else

def time_description_to_seconds(td):
    if type(td) in (int, float):
        return float(td)
    for sufix, multiplier in td_to_s_multiplier:
        if td.endswith(sufix):
            return float(td[:-len(sufix)])*multiplier
    return float(td)

def url_to_opts(url):
    """
    Url must be an `ssh://username:password@hostname:port/` with all optional
    except hostname. It can be just `username@hostname`, or even `hostname`
    """
    if not '//' in url:
        url="ssh://"+url
    u = urlparse.urlparse(url)
    assert u.scheme == 'ssh'

    ret= [ u.hostname, '-i', ID_RSA, '-F', CONFIG_FILE ]
    if u.port:
        ret +=["-p", str(u.port)]
    if u.username:
        ret[0]=u.username+'@'+u.hostname
    return (ret, u)

@serverboards.rpc_method
def ssh_exec(url=None, command="test", options=None, service=None):
    serverboards.debug(repr(dict(url=url, command=command, options=options, service=service)))
    ensure_ID_RSA()
    if options:
        serverboards.warning("ssh_exec options deprecated. Better use ssh_exec by ssh service uuid. Currently ignored.")
    if not command:
        raise Exception("Need a command to run")
    if url:
        serverboards.warning("ssh_exec by URL deprecated. Better use ssh_exec by ssh service uuid")
        (args, url) = url_to_opts(url)
        global_options=(serverboards.rpc.call("settings.get","serverboards.core.ssh/ssh.settings", None) or {}).get("options","")
        options =global_options+"\n"+(options or "")
        args += [
            arg.strip()
            for option in options.split('\n') if option
            for arg in ['-o',option]
            ]
        args = [x for x in args if x] # remove empty
    else:
        url, args = __get_service_url_and_opts(service)
    args += ['--', command]
    serverboards.debug("Executing SSH command: [ssh] %s"%(args))
    # Each argument is an element in the list, so the command, even if it
    # contains ';' goes all in an argument to the SSH side
    sp=pexpect.spawn("/usr/bin/ssh", args)
    running=True
    while running:
        ret=sp.expect([re.compile(b'^(.*)\'s password:'), pexpect.EOF])
        data=sp.before
        if ret==1:
            running=False
        elif ret==0:
            if not url.password:
                serverboards.error("Could not connect url %s, need password"%(repr(url)))
                raise Exception("Need password")
            sp.sendline(url.password)
    sp.wait()

    stdout = data.decode('utf8')

    if service:
        serverboards.info("SSH Command executed %s'%s'"%(service, command), extra=dict(service_id=service, command=command, stdout=stdout))
    return {"stdout": stdout, "exit": sp.exitstatus}

sessions={}
import uuid

@serverboards.rpc_method("open")
def _open(url, uidesc=None, options=""):
    ensure_ID_RSA()
    if not uidesc:
        uidesc=url
    options=[x for x in options.split('\n') if x]

    (opts, url) = url_to_opts(url)
    options = __get_global_options() + options
    opts += [
        arg.strip()
        for option in options
        for arg in ['-o',option]
        ]
    opts += ['-t','-t', '--', '/bin/bash']
    (ptymaster, ptyslave) = pty.openpty()

    sp=subprocess.Popen(["/usr/bin/ssh"] + opts,
        stdin=ptyslave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    _uuid = str(uuid.uuid4())
    sessions[_uuid]=dict(process=sp, buffer=b"", end=0, uidesc=uidesc, ptymaster=ptymaster)

    serverboards.rpc.add_event(sp.stdout, lambda :new_data_event(_uuid) )

    return _uuid

@serverboards.rpc_method
def close(uuid):
    sp=sessions[uuid]
    serverboards.rpc.remove_event(sp['process'].stdout)
    sp['process'].kill()
    sp['process'].wait()
    del sp['process']
    del sessions[uuid]
    return True

@serverboards.rpc_method
def list():
    return [(k, v['uidesc']) for k,v in sessions.items()]

@serverboards.rpc_method
def send(uuid, data=None, data64=None):
    """
    Sends data to the terminal.

    It may be `data` as utf8 encoded, or `data64` as base64 encoded

    data64 is needed as control charaters as Crtl+L are not utf8 encodable and
    can not be transmited via json.
    """
    sp=sessions[uuid]
    if not data:
        data=base64.decodestring(bytes(data64,'utf8'))
    else:
        data=bytes(data, 'utf8')
    #ret = sp.send(data)
    ret = os.write( sp["ptymaster"], data )
    return ret

@serverboards.rpc_method
def send_control(uuid, type, data):
    """
    Sends control data to the terminal, as for example resize events
    """
    sp=sessions[uuid]
    if type=='resize':
        import termios
        import struct
        import fcntl

        winsize = struct.pack("HHHH", data['rows'], data['cols'], 0, 0)
        fcntl.ioctl(sp['ptymaster'], termios.TIOCSWINSZ, winsize)

        return True
    else:
        serverboards.warning("Unknown control type: %s"%(type))
        return False

@serverboards.rpc_method
def sendline(uuid, data):
    return send(uuid, data+'\n')

def new_data_event(uuid):
    sp=sessions[uuid]
    raw_data = os.read( sp['process'].stdout.fileno(), 4096 )
    if not raw_data:
        serverboards.rpc.event("event.emit", "terminal.data.received.%s"%uuid, {"eof": True, "end": sp["end"]})
        serverboards.rpc.remove_event(sp['process'].stdout)
        sp['process'].wait(1) # wait a little bit, normally will be already exited
        return
    sp['buffer']=(sp['buffer'] + raw_data)[-4096:] # keep last 4k
    sp['end']+=len(raw_data)

    data = str( base64.encodestring( raw_data ), 'utf8' )
    serverboards.rpc.event("event.emit", "terminal.data.received.%s"%uuid, {"data64": data, "end": sp["end"]})

@serverboards.rpc_method
def recv(uuid, start=None, encoding='utf8'):
    """
    Reads some data from the ssh end.

    It may be encoded for transmission. Normally all text is utf8, but control
    chars are not, and they can not be converted for JSON encoding. Thus base64
    is allowed as encoding.

    It can receive a `start` parameter that is from where to start the buffer to
    return. The buffer has a position from the original stream, and all data
    returns to the end of that stream position. Its possible to ask from a specific
    position and if available will be returned. If its none returns all buffer.

    This can be used to regenerate the terminal status from latest 4096 bytes. On
    most situations may suffice to restore current view. Also can be used to do
    polling, although events are recomended.
    """
    sp = sessions[uuid]
    raw_data = sp['buffer']
    bend = sp['end']
    bstart = bend-len(raw_data)

    i=0 # on data buffer, where to start
    if start is not None:
        if start<bstart:
            raise Exception("Data not in buffer")
        elif start>bend:
            i=len(raw_data) # just end
        else:
            i=start-bstart
    raw_data=raw_data[i:]
    print(raw_data, repr(raw_data))
    if encoding=='b64':
        data = str( base64.encodestring(raw_data), 'utf8' )
    else:
        data = str( raw_data, encoding )
    return {'end': bend, 'data': data }

port_to_pexpect={}
open_ports={}

@cache_ttl(ttl=60)
def __get_service_url_and_opts(service_uuid):
    assert service_uuid, "Need service UUID"
    service = __get_service(service_uuid)
    if not service or service["type"] != "serverboards.core.ssh/ssh":
        raise Exception("Could not get information about service")
    url = service["config"]["url"]

    options = [ x.strip() for x in service["config"].get("options","").split('\n') if x ]
    options = __get_global_options() + options
    options = [
        arg
        for option in options
        for arg in ['-o',option] # flatten -o option
        ]

    conn_opts, url = url_to_opts(url)
    options += conn_opts

    return (url, options)

@serverboards.rpc_method
def open_port(url=None, ssh_service=None, hostname="localhost", port="22"):
    """
    Opens a connection to a remote ssh server on the given hostname and port.

    This will make a local port accesible that will be equivalen to the remote
    one. The local one is random.

    Arguments:
        url --  The ssh server url, as ssh://[username@]hostname[:port], or
                simple hostname (required or ssh_service)
        ssh_service -- UUID of the proxying service, instead of the URL.
        hostname -- Remote hostname to connect to. Default `localhost` which
                would be the SSH server
        port -- Remote port to connect to

    Returns:
     localport -- Port id on Serverboards side to connect to.
    """
    ensure_ID_RSA()
    if url:
        serverboards.warning("Deprecated open port by URL. Better use open port by service UUID, as it uses all SSH options.")
        (opts, url) = url_to_opts(url)
    else:
        assert ssh_service
        (url, opts) = __get_service_url_and_opts(ssh_service)
        serverboards.debug("Service %s url is %s"%(ssh_service, url))

    if url in open_ports:
        return open_ports[url]

    keep_trying=True
    while keep_trying:
        localport=random.randint(20000,60000)
        mopts=opts+["-nNT","-L","%s:%s:%s"%(localport, hostname, port)]
        serverboards.debug("Start ssh with opts: %s"%mopts)
        sp=pexpect.spawn("/usr/bin/ssh",mopts)
        port_to_pexpect[localport]=sp
        running=True
        while running:
            ret=sp.expect([str('^(.*)\'s password:'), str('Could not request local forwarding.'), pexpect.EOF, pexpect.TIMEOUT], timeout=2)
            if ret==0:
                if not url.password:
                    serverboards.error("Could not connect url %s, need password"%( url.geturl() ))
                    raise Exception("Need password")
                    sp.sendline(url.password)
            if ret==1:
                running=False
                del port_to_pexpect[localport]
            if ret==2:
                keep_trying=False
                running=False
            if ret==3:
                keep_trying=False
                running=False
    open_ports[url]=localport
    serverboards.debug("Port redirect localhost:%s -> %s:%s"%(localport, hostname, port))
    return localport

@serverboards.rpc_method
def close_port(port):
    """
    Closes a remote connected port.

    Uses the local port as identifier to close it.
    """
    port_to_pexpect[port].close()
    del port_to_pexpect[port]
    global open_ports
    open_ports = { url:port for url,port in open_ports.items() if port != port}
    serverboards.debug("Closed port redirect localhost:%s"%(port))
    return True

@serverboards.rpc_method
def watch_start(id=None, period=None, service=None, script=None, **kwargs):
    period_s = time_description_to_seconds(period or "5m")
    service_uuid=service["uuid"]
    class Check:
        def __init__(self):
            self.state=None
        def check_ok(self):
            stdout=None
            try:
                p = ssh_exec(service=service_uuid, command=script)
                stdout=p["stdout"]
                p = (p["exit"] == 0)
                serverboards.info(
                    "SSH remote check script: %s: %s"%(script, p),
                    extra=dict(
                        rule=id,
                        service=service_uuid,
                        script=script,
                        stdout=stdout,
                        exit_code=p)
                    )
            except:
                serverboards.error("Error on SSH script: %s"%script, extra=dict(rule=id, script=script, service=service["uuid"]))
                p = False
            nstate = "ok" if p else "nok"
            if self.state != nstate:
                serverboards.rpc.event("trigger", {"id":id, "state": nstate})
                self.state=nstate
            return True
    check = Check()
    check.check_ok()
    timer_id = serverboards.rpc.add_timer(period_s, check.check_ok)
    serverboards.info("Start SSH script watch %s"%timer_id)
    return timer_id

@serverboards.rpc_method
def watch_stop(id):
    serverboards.info("Stop SSH script watch %s"%(id))
    serverboards.rpc.remove_timer(id)
    return "ok"

@cache_ttl(ttl=10)
def __get_service_url(uuid):
    data = __get_service(uuid)
    # serverboards.info("data: %s -> %s"%(uuid, data))
    return data["config"].get("url")

@cache_ttl(ttl=60)
def __get_service(uuid):
    data = serverboards.rpc.call("service.get", uuid)
    # serverboards.info("data: %s -> %s"%(uuid, data))
    return data

@cache_ttl(ttl=300)
def __get_global_options():
    options = try_or(
        lambda: serverboards.rpc.call("settings.get","serverboards.core.ssh/ssh.settings"),
        {}
      ).get("options","").split('\n')
    options = [ o.strip() for o in options ]
    options = [ o for o in options if o ]
    return options

@serverboards.rpc_method
def scp(fromservice=None, fromfile=None, toservice=None, tofile=None):
    """
    Copies a file from a service to a service.

    It gets the data definition of the service (how to access) from serverboards
    core, so any plugin with SSH access can do this copies.

    It knows about options at URL definition, but only for one side (from or to).

    It is recommeneded to use it only to copy from/to host.
    """
    assert fromfile and tofile
    assert not (fromservice and toservice)
    serverboards.info("Copy from %s:%s to %s:%s"%(fromservice, fromfile, toservice, tofile))
    opts=[]
    if fromservice:
        url = __get_service_url(fromservice)
        opts, _url = url_to_opts(url)
        url=opts[0]
        opts=opts[1:]
        urla = "%s:%s"%(url, fromfile)
    else:
        urla=fromfile

    if toservice:
        opts, _url = url_to_opts(__get_service_url(toservice))
        url=opts[0]
        opts=opts[1:]
        urlb = "%s:%s"%(url, tofile)
    else:
        urlb=tofile
    serverboards.info("scp %s %s %s"%(' '.join(opts), urla, urlb))
    try:
        sh.scp(*opts, urla, urlb).stdout.decode("utf8")
        return True
    except Exception as e:
        raise Exception(e.stderr)

@serverboards.rpc_method
def run(url=None, command=None, service=None):
    if url:
        return ssh_exec(url=url, command=command)
    assert service and command
    serverboards.info("Run %s:'%s'"%(service, command))
    return ssh_exec(service=service, command=command)

@serverboards.rpc_method
def popen(service_uuid, command):
  url,opts = __get_service_url_and_opts(service_uuid)
  opts=opts+["--"]+command
  ssh = subprocess.Popen(["ssh"]+opts, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
  # adapter from pipe at the ssh to the s10s pipes, one for each stdin/out
  write_in_fd, write_out_fd = file.pipe(async=True)
  read_in_fd, read_out_fd = file.pipe(async=True)

  print("Write fds: ", write_in_fd, write_out_fd)
  print("Read fds: ", read_in_fd, read_out_fd)
  # store all subscriptions, to unsubscribe at closed
  subscriptions=[]

  def write_to_ssh():
    block = file.read(write_out_fd, { "nonblock": True })
    closed=False
    if block == -1:
      closed=True
    while block and block!=-1:
      print("Write to %s %d bytes, read from %s"%(command[0], len(block), write_out_fd))
      ssh.stdin.write( base64.b64decode( block.encode('ascii') ) )
      ssh.stdin.flush()
      block = file.read(write_out_fd, { "nonblock": True })
    if closed:
      file.close(write_out_fd)
      close_all()

  MAX_SIZE=16*1024
  counter=0
  def read_from_ssh():
    block = ssh.stdout.read(MAX_SIZE)
    nonlocal counter
    closed = False
    if not block: # if nothing to read on first call, the fd is closed
      closed = True
    while block:
      counter+=1
      print("Read from %s %d bytes, write to %s"%(command[0], len(block), read_in_fd))
      ## BUG They are being read on the other popen in the wrong order! maybe queuing at the pipe in the wrong order
      file.write(read_in_fd, base64.b64encode( b"\n[[%d]]\n%s"%(counter, block) ).decode('ascii') )
      block = ssh.stdout.read(MAX_SIZE)
    if closed:
      file.sync(read_in_fd)
      file.close(read_in_fd)
      close_all()

  def close_all():
    file.close(write_out_fd)
    serverboards.rpc.remove_event( ssh.stdout )
    file.close(read_in_fd)
    for s in subscriptions:
      serverboards.rpc.unsubscribe(s)
    print("Flush and terminate")
    ssh.stdin.flush()
    if ssh.poll() != None:
      try:
        ssh.terminate()
        #time.sleep(1)
        #ssh.kill()
      except:
        pass
      print("SSH command %s terminated"%(command[0]))

  s=serverboards.rpc.subscribe( "file.ready[%s]"%write_out_fd, write_to_ssh )
  subscriptions.append(s)
  s=serverboards.rpc.subscribe( "file.closed[%s]"%read_in_fd, close_all )
  subscriptions.append(s)
  s=serverboards.rpc.subscribe( "file.closed[%s]"%write_out_fd, close_all )
  subscriptions.append(s)

  serverboards.rpc.add_event( ssh.stdout, read_from_ssh )

  return [write_in_fd, read_out_fd]

if __name__=='__main__':
    if len(sys.argv)==2 and sys.argv[1]=='test':
        #print(ssh_exec("localhost","ls -l | tr -cs '[:alpha:]' '\\\\n' | sort | uniq -c | sort -n"))
        #print(ssh_exec("ssh://localhost:22","ls -l | tr -cs '[:alpha:]' '\\\\n' | sort | uniq -c | sort -n"))
        #import time
        #localhost = open("localhost")
        #send(localhost,"ls /tmp/\n")
        #time.sleep(1.000)
        #print()
        #print(recv(localhost))
        #print()

        import time
        called=[]
        @cache_ttl(ttl=0.25, maxsize=3)
        def test(p):
            print("Called!")
            called.append(p)
            return len(called)

        assert test(1) == 1
        assert test(1) == 1
        assert test(2) == 2
        assert test(1) == 1
        time.sleep(0.5)
        assert test(1) == 3
        assert test(1) == 3
        assert test(2) == 4
        assert test(1) == 3
        time.sleep(0.5)
        assert test(1) == 5
        assert test(2) == 6
        assert test(3) == 7
        assert test(4) == 8
        assert test(1) == 9 # should be in cache, but maxsize achieved

    else:
        serverboards.loop()
