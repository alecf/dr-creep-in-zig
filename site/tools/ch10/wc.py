import sys,re
s=open(sys.argv[1]).read()
s=s.split('---',2)[2]
prose=[];code=[];inf=False
for l in s.split('\n'):
    if l.startswith('```'):
        inf=not inf; continue
    (code if inf else prose).append(l)
pw=len(' '.join(prose).split()); cw=len(' '.join(code).split())
print('prose',pw,'code',cw,'total',pw+cw)
