import sockets, strutils, strtabs, parseutils

type
  TUrbanTerror = object
    sock: TSocket
    rcon: string

  TStatus = object
    options: PStringTable
    players: seq[tuple[nick, score, ping: string]]

  EUrbanTerror = object of ESynch

const
  magic = "\xFF\xFF\xFF\xFF"

proc connect*(address: string, rcon: string = "", port: int = 27960): TUrbanTerror =
  result.sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  assert(result.sock != InvalidSocket)
  result.sock.connect(address, TPort(port))

  result.rcon = rcon

proc sendCommand*(urt: TUrbanTerror, command: string): string =
  # Send:
  urt.sock.send(magic & command & "\n")
  # Receive:
  var line: array[0..2048, char]
  assert urt.sock.recv(addr(line), 2048) != 0
  return $line

proc skipUntil(s: string, token: char, start = 0): int =
  ## Skips all characters until \ or \r or \L is found. Returns number of
  ## characters skipped.
  var i = start
  while True:
    if s[i] == token or s[i] == '\c' or s[i] == '\L':
      return i - start
    inc(i)
    
proc parseStatus*(msg: string): TStatus =
  ## Parses a status message giving a string table of server options and a list
  ## of players; their scores and ping.

  result.options = newStringTable(modeCaseInsensitive)
  result.players = @[]

  var i = msg.skip(magic & "statusResponse\n")
  if i == 0: raise newException(EUrbanTerror, "Msg is not a status response.")
  
  while True:
    if msg[i] == '\c' or msg[i] == '\L':
      break
    # Skip \
    inc(i)
    # Skip until next \
    var keyLen = msg.skipUntil('\\', i)
    var key = copy(msg, i, keyLen + i - 1)
    inc(i, keyLen)
    # Skip \
    inc(i)
    # Skip until next \
    var valueLen = msg.skipUntil('\\', i)
    var value = copy(msg, i, valueLen + i - 1)
    inc(i, valueLen)
    
    result.options[key] = value
  
  # Players
  while True:
    if msg[i] == '\c': inc(i)
    if msg[i] == '\L': inc(i)
    if msg[i] == '\0': break

    # Skip until next space
    var scoreLen = msg.skipUntil(' ', i)
    var score = msg.copy(i, scoreLen + i - 1)
    inc(i, scoreLen + 1) # Skip score plus space

    var pingLen = msg.skipUntil(' ', i)
    var ping = msg.copy(i, pingLen + i - 1)
    inc(i, pingLen + 1) # Skip ping plus space

    var nickLen = msg.skipUntil('\L', i) # Nicks can have spaces.
    var nick = msg.copy(i, nickLen + i - 1)
    inc(i, nickLen + 1) # Skip nick plus space
    
    result.players.add((nick, score, ping))

proc getStatus*(urt: TUrbanTerror): TStatus =
  return parseStatus(urt.sendCommand("getstatus"))

when isMainModule:
  var urt = connect("87.98.137.207")

  var parsed = urt.getStatus()
  for key, value in pairs(parsed.options):
    echo("\"$1\": $2" % @[key, value])
  
  echo("--- Players: $1 ---" % @[$len(parsed.players)])
  
  for nick, score, ping in items(parsed.players):
    echo("$1 - $2($3)" % @[nick, score, ping])
