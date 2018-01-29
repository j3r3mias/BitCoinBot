TOKEN=SEU_TOKEN
CHATID=SEU_CHAT_ID
ADMINS=( lista de admins separada por espaço )
INTERVALO="5"
BTCMAX="11000"
BTCMIN="9500"
LTCMAX="150"
LTCMIN="111"
PORCENTAGEM="4"
last="oe"
foxbiturl="https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC"
apiurl="https://api.telegram.org/bot$TOKEN"
mbtc=https://www.mercadobitcoin.net/api
coinmarketcap=https://api.coinmarketcap.com/v1/ticker
COMANDOS="^/cotacoes$|\
^/[lb]tcm[ai][xn] [0-9]+$|\
^/help$|^/parametros$|\
^/intervalo [0-9]+(\.[0-9])?$|\
^/porcentagem [0-9]{1,2}(\.[0-9]{1,2})?$|\
^/coin( [a-zA-Z0-9.-]+){1,2}$|\
^/adiciona [0-9a-zA-Z-]+ -?[0-9]+(\.[0-9]+)?$|\
^/remove [0-9a-zA-Z-]+$|\
^/consulta$"
