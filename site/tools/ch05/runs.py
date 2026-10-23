# The headless runs for each stage of the rebuild; F is the Boss Battle.
LADDERS = ['--frames', '520', '--press', '20:f:5', '--key', '60:N', '--key', '100:N', '--press', '120:r:176', '--press', '300:u:80', '--press', '390:r:130', '--dump-every', '20']
BELL = ['--frames', '300', '--press', '20:f:5', '--press', '60:l:34', '--press', '100:f:5', '--press', '160:r:20', '--press', '200:ur:10', '--dump-every', '10']
DOORS = ['--frames', '1500', '--press', '20:f:5', '--press', '60:l:34', '--press', '100:f:5', '--press', '160:r:20', '--press', '200:ur:10',
         '--press', '350:r:180', '--press', '540:f:5', '--press', '600:r:40', '--press', '650:ur:10', '--press', '840:r:176', '--press', '1020:u:80',
         '--press', '1100:r:60', '--press', '1165:f:5', '--press', '1220:r:30', '--press', '1255:ur:10', '--dump-every', '10']
BOSS = DOORS[:1] + ['2300'] + DOORS[2:-2] + ['--press', '1500:r:96', '--press', '1600:d:70', '--press', '1675:r:140', '--press', '1820:f:5',
       '--press', '1880:r:30', '--press', '1915:ur:10', '--key', '2150:X', '--dump-every', '10']
DEATH = ['--frames', '400', '--press', '20:f:5', '--press', '50:l:30', '--key', '90:X', '--key', '200:X', '--key', '300:X', '--dump-every', '10']
RUNS = {
    'A': LADDERS,
    'B': LADDERS,
    'C': BELL,
    'D': DOORS,
    'E': DEATH,
    'F': BOSS,
}
