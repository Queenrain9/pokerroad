from itertools import combinations
import random,pytest
from poker_reference import DECK,score5,score,settle,can_register,affordable_jobs
@pytest.mark.parametrize('cards,category',[('AsKsQsJsTs',8),('9s9h9d9c2s',7),('AsAhAdKsKd',6),('AsJs8s4s2s',5),('As2h3d4c5s',4),('AsAhAdKsQs',3),('AsAhKsKh2d',2),('AsAhKsQh2d',1),('AsKsQsJd9h',0)])
def test_nine_hand_categories(cards,category): assert score5([cards[i:i+2] for i in range(0,len(cards),2)])[0]==category
def test_ace_low_straight_not_six_high():
    assert score5(['As','2h','3d','4c','5s'])==(4,5);assert score5(['As','Ks','Qs','Js','Ts'])==(8,14)
def test_seven_card_best_full_house(): assert score(['As','Ah','Ad','Ks','Kd','2h','3d'])==(6,14,13)
def test_seven_card_pair_kicker():
    b=['Ad','7s','6c','4h','2d'];assert score(['As','Kc']+b)>score(['Ah','Qc']+b)
def test_common_board_tie():
    b=['As','Ks','Qs','Js','Ts'];assert score(['2h','3d']+b)==score(['4h','5d']+b)
def test_duplicate_cards_rejected():
    with pytest.raises(ValueError):score(['As','As','Qs','Js','Ts'])
    with pytest.raises(ValueError):score(['As','Ks','Qs','Js'])
def test_all_52_cards_unique(): assert len(DECK)==52 and len(set(DECK))==52
def test_one_short_allin_creates_sidepot():
    b=['Ah','Kh','Qh','Jd','2c'];r=settle([20,50,50],[True,True,True],[['Th','9s'],['Ad','3c'],['Kd','4c']],b)
    assert [p['amount'] for p in r['pots']]==[60,60] and sum(r['payouts'])==120
def test_folded_contribution_stays_in_pot():
    b=['Ah','Kh','Qh','Jd','2c'];r=settle([20,50,50],[True,False,True],[['Th','9s'],[],['Kd','4c']],b);assert r['payouts'][1]==0 and sum(r['payouts'])==120
def test_uncalled_amount_refunded():
    b=['Ah','Kh','Qh','Jd','2c'];s=settle([20,50,50,90],[True,True,True,True],[['Th','9s'],['Ad','3c'],['Kd','4c'],['2s','2d']],b);assert s['refunds']==[0,0,0,40] and sum(s['payouts'])==170
def test_odd_chip_clockwise_left_of_dealer():
    b=['As','Ks','Qs','Js','Ts'];s=settle([1,1,1],[True,True,False],[['2h','3d'],['4h','5d'],[]],b,dealer=0);assert s['payouts']==[1,2,0]
def test_zero_chip_no_false_story_lock():
    assert affordable_jobs(0,0,10)==0 and affordable_jobs(0,31,10)==4 and affordable_jobs(0,31,0) is None
    assert not can_register('PENDING','OFFICIAL',True,True) and can_register('YES','OFFICIAL',True,True)
def test_random_chip_conservation_one_active_live():
    rng=random.Random(250925)
    for _ in range(1000):
        n=rng.randint(2,8);c=[rng.randint(0,1000) for _ in range(n)];live=[False]*n;live[rng.randrange(n)]=True;c[live.index(True)]=max(c)
        result=settle(c,live,[[] for _ in range(n)],['As','Ks','Qs','Js','Ts']);assert sum(result['payouts'])+sum(result['refunds'])==sum(c)
def test_random_multiway_showdown_conserves_chips():
    rng=random.Random(250926)
    for _ in range(250):
        n=rng.randint(2,8);deck=rng.sample(DECK,5+2*n);board=deck[:5];hands=[deck[5+i*2:7+i*2] for i in range(n)];chips=[rng.randint(1,1000) for _ in range(n)]
        result=settle(chips,[True]*n,hands,board,dealer=rng.randrange(n));assert sum(result['payouts'])+sum(result['refunds'])==sum(chips)
def test_each_exactly_five_card_hand_category_counts():
    rng=random.Random(2026)
    for _ in range(3000): assert score5(rng.sample(DECK,5))[0] in range(9)
