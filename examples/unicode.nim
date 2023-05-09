import nico

var messages = @[
    ("English", "!\"#$%&'()*+,-./0123456789\n:;<=>?@abcdefghijklmnopqrstuvwxyz\n[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{}~"),
    ("German", "Falsches Üben von Xylophonmusik quält jeden größeren Zwerg"),
    ("German", "Beiß nicht in die Hand, die dich füttert."),
    ("German", "Außerordentliche Übel erfordern außerordentliche Mittel."),
    ("Armenian", "Կրնամ ապակի ուտել և ինծի անհանգիստ չըներ"),
    ("Armenian", "Երբ որ կացինը եկաւ անտառ, ծառերը ասացին... «Կոտը մերոնցից է:»"),
    ("Armenian", "Գառը՝ գարնան, ձիւնը՝ ձմռան"),
    ("Polish", "Jeżu klątw, spłódź Finom część gry hańb!"),
    ("Polish", "Dobrymi chęciami jest piekło wybrukowane."),
    ("Romanian", "Îți mulțumesc că ai ales nico.\nȘi sper să ai o zi bună!"),
    ("Russian", "Эх, чужак, общий съём цен шляп (юфть) вдрызг!"),
    ("Russian", "Я люблю nico!"),
    ("Russian", "Молчи, скрывайся и таи\nИ чувства и мечты свои –\nПускай в душевной глубине\nИ всходят и зайдут оне\nКак звезды ясные в ночи-\nЛюбуйся ими – и молчи."),
    ("French", "Voix ambiguë d’un cœur qui au zéphyr préfère les jattes de kiwi"),
    ("Spanish", "Benjamín pidió una bebida de kiwi y fresa; Noé, sin vergüenza, la más exquisita champaña del menú."),
    ("Greek", "Ταχίστη αλώπηξ βαφής ψημένη γη, δρασκελίζει υπέρ νωθρού κυνός"),
    ("Greek", "Η καλύτερη άμυνα είναι η επίθεση."),
    ("Greek", "Χρόνια και ζαμάνια!"),
    ("Greek", "Πώς τα πας σήμερα;"),
    ("Chinese", "我能吞下玻璃而不伤身体。"),
    ("Chinese", "你吃了吗？"),
    ("Chinese", "不作不死。"),
    ("Chinese", "最近好吗？"),
    ("Chinese", "塞翁失马，焉知非福。"),
    ("Chinese", "千军易得, 一将难求"),
    ("Chinese", "万事开头难。"),
    ("Chinese", "风无常顺，兵无常胜。"),
    ("Chinese", "活到老，学到老。"),
    ("Chinese", "一言既出，驷马难追。"),
    ("Chinese", "路遥知马力，日久见人心"),
    ("Chinese", "有理走遍天下，无理寸步难行。"),
    ("Japanese", "猿も木から落ちる"),
    ("Japanese", "亀の甲より年の功"),
    ("Japanese", "うらやまし 思ひ切る時 猫の恋"),
    ("Japanese", "虎穴に入らずんば虎子を得ず。"),
    ("Japanese", "二兎を追う者は一兎をも得ず。"),
    ("Japanese", "馬鹿は死ななきゃ治らない。"),
    ("Japanese", "枯野路に　影かさなりて　わかれけり"),
    ("Japanese", "繰り返し麦の畝縫ふ胡蝶哉"),
    ("Korean", "아득한 바다 위에 갈매기 두엇 날아 돈다.\n너훌너훌 시를 쓴다. 모르는 나라 글자다.\n널따란 하늘 복판에 나도 같이 시를 쓴다."),
    ("Korean", "제 눈에 안경이다"),
    ("Korean", "꿩 먹고 알 먹는다"),
    ("Korean", "로마는 하루아침에 이루어진 것이 아니다"),
    ("Korean", "고생 끝에 낙이 온다"),
    ("Korean", "개천에서 용 난다"),
    ("Korean", "안녕하세요?"),
    ("Korean", "만나서 반갑습니다"),
    ("Korean", "한국말 하실 줄 아세요?"),
  ]

var langs = @[
"quan.png",
"ChillBitmap7x.png",
"font.png"
]
var langIdx = 0
proc gameInit() =
  for i in 0..<langs.len:
    loadFont(i, langs[i])

  setWindowTitle("[ " & langs[langIdx][0..^5] & " ] font")
  discard

var iFrame: int
var isPrintr: bool
proc gameUpdate(dt: float32) =
  if keyp(K_ESCAPE): shutdown()
  if keyp(K_SPACE) or iFrame > 1000:
    langIdx.inc
    if langIdx >= langs.len:
      isPrintr = not isPrintr
    langIdx = langIdx mod langs.len
    iFrame = 0
    setFont(langIdx)
    setWindowTitle("[ " & langs[langIdx][0..^5] & " ] font")
  iFrame.inc
  discard

import strformat
proc gameDraw() =
  cls()
  var
    rcolor {.global.} = rnd(1, 15)
    scale {.global.} = 1
  block unicode:
    #break
    var
      color = rcolor
      h,i = 0
    if iFrame < 2: rcolor = rnd(1, 15)
    for (language, msg) in messages:
      if h > screenHeight:
        cls()
        h = 0
      setColor(color)
      if not isPrintr:
        print(&"{language}: {msg}", 0, h, scale)
      else:
        printr(&"{language}: {msg}", screenWidth, h, scale)
      h += msg.textHeight(scale)
      color.inc
      color = color mod 15 + 1 # rnd(1,16)
      i.inc
      if i > iFrame div 20: break
    discard

  setColor(6)
  printr(&"frame: {iFrame}", screenWidth, screenHeight - fontHeight())
  printr("font: " & langs[langIdx][0..^5], screenWidth, screenHeight - fontHeight() * 2 * scale - scale)
  discard

nico.init("nico", "unicode test")
nico.createWindow("nico", 384, 384, 2, false)
fixedSize(true)
integerScale(true)
nico.run(gameInit, gameUpdate, gameDraw)
