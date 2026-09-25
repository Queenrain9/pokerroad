"""Offline arithmetic oracle for planning + comparisons with production GDScript.
Does not constitute a full poker game engine or device QA.
"""
from collections import Counter
from itertools import combinations
RANKS='23456789TJQKA'; SUITS='shdc'; DECK=[r+s for r in RANKS for s in SUITS]
def score5(cards):
    if len(cards)!=5 or len(set(cards))!=5 or any(len(c)!=2 or c[0] not in RANKS or c[1] not in SUITS for c in cards): raise ValueError('invalid card set')
    values=[RANKS.index(c[0])+2 for c in cards]; ranks=sorted(values,reverse=True); counts=Counter(values)
    by_count=lambda n:sorted((r for r,v in counts.items() if v==n),reverse=True)
    fours,threes,pairs,singles=(by_count(n) for n in (4,3,2,1)); straight=0; distinct=sorted(counts,reverse=True)
    if len(distinct)==5:
        if distinct[0]-distinct[-1]==4: straight=distinct[0]
        elif distinct==[14,5,4,3,2]: straight=5
    flush=len({c[1] for c in cards})==1
    if straight and flush:return (8,straight)
    if fours:return (7,fours[0],singles[0])
    if threes and pairs:return (6,threes[0],pairs[0])
    if flush:return (5,*ranks)
    if straight:return (4,straight)
    if threes:return (3,threes[0],*singles)
    if len(pairs)==2:return (2,*pairs,singles[0])
    if pairs:return (1,pairs[0],*singles)
    return (0,*ranks)
def score(cards):
    if not 5<=len(cards)<=7 or len(set(cards))!=len(cards): raise ValueError('invalid card count or duplicate')
    return max(score5(cs) for cs in combinations(cards,5))
def settle(contributions,live,hands,board,dealer=-1):
    n=len(contributions)
    if not (n>=2 and len(live)==n and len(hands)==n and len(board)==5) or sum(live)<1: raise ValueError('invalid seat data')
    if any(not isinstance(v,int) or v<0 for v in contributions): raise ValueError('negative or noninteger wager')
    known=list(board)+[c for hand in hands for c in hand]
    if len(known)!=len(set(known)) or any(c not in DECK for c in known): raise ValueError('invalid/repeated physical card')
    if any(len(hands[i])!=2 for i in range(n) if live[i] and sum(live)>1): raise ValueError('missing live hole cards')
    payout=[0]*n; refund=[0]*n; pots=[]; prior=0
    for level in sorted(set(x for x in contributions if x>0)):
        contrib=[i for i in range(n) if contributions[i]>=level]; eligible=[i for i in contrib if live[i]]
        amount=(level-prior)*len(contrib); prior=level
        if len(contrib)==1:
            refund[contrib[0]]+=amount; pots.append({'amount':amount,'refund':contrib[0]}); continue
        if not eligible: raise ValueError('orphan pot')
        if len(eligible)==1:winners=eligible
        else:
            sc={i:score(hands[i]+board) for i in eligible}; high=max(sc.values()); winners=[i for i in eligible if sc[i]==high]
        each,odd=divmod(amount,len(winners))
        for i in winners:payout[i]+=each
        first=(dealer+1)%n
        for d in range(n):
            i=(first+d)%n
            if odd and i in winners:payout[i]+=1;odd-=1
        pots.append({'amount':amount,'eligible':eligible,'winners':winners})
    assert sum(payout)+sum(refund)==sum(contributions)
    return {'payouts':payout,'refunds':refund,'pots':pots}
def can_register(q,intent,deadline_open,seat_left,evidence_valid=True):
    return q=='YES' and intent=='OFFICIAL' and deadline_open and seat_left and evidence_valid
def affordable_jobs(chips,fee,reward):
    if any(not isinstance(x,int) or x<0 for x in [chips,fee,reward]):raise ValueError('negative balance')
    if chips>=fee:return 0
    if reward==0:return None
    return (fee-chips+reward-1)//reward
