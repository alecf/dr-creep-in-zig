# Ladders room navigation grid, mirroring grid.add / grid.piece (code/ch04/src/grid.zig)
UP,RIGHT,DOWN,LEFT=1,4,0x10,0x40
def build():
    g=[[0]*40 for _ in range(25)]
    runs=[('walkway',40,16,192),('walkway',20,96,128),('ladder',9,112,128)]
    for k,n,x,y in runs:
        for i in range(1,n+1):
            if x>=176 or y>=200: break
            if x>=16:
                c=x//4-4; r=y//8
                if k=='walkway': w=RIGHT if i==1 else LEFT if i==n else LEFT|RIGHT
                else: w=(UP if i!=1 else 0)|(DOWN if i!=n else 0)
                g[r][c]|=w
            if k=='walkway': x+=4
            else: y+=8
    return g
if __name__=='__main__':
    g=build()
    for r in range(14,25): print(r, ' '.join('%02X'%v for v in g[r][18:40]))
