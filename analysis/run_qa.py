from pathlib import Path
import argparse,subprocess,sys,time
from collections import Counter
from itertools import combinations
p=argparse.ArgumentParser();p.add_argument('--exhaustive',action='store_true');a=p.parse_args()
code=subprocess.call([sys.executable,'-m','pytest','-q'],cwd=Path(__file__).parent)
if code:sys.exit(code)
if a.exhaustive:
 sys.path.insert(0,str(Path(__file__).parent));from poker_reference import DECK,score5
 t=time.monotonic();cnt=Counter(score5(h)[0] for h in combinations(DECK,5))
 expected={0:1302540,1:1098240,2:123552,3:54912,4:10200,5:5108,6:3744,7:624,8:40}
 assert dict(cnt)==expected,(cnt,expected)
 print(f'EXHAUSTIVE_OK: {sum(cnt.values()):,} exact 5-card combinations; {time.monotonic()-t:.2f}s')
print('Godot runtime and iOS/Android are NOT tested by this Python QA command.')
