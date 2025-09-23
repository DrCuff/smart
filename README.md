# smart vibes: on vibe coding ~900 lines of bash and awk... 

There is no need for any of this.  Not at all.  

Background story, I bought a 6 drive thunderbolt from ebay for two hundred notes. It used to cost about 2 grand and came in 6 and 12TB variants.  In 2011, cnet wasn't all that impressed:  

[https://www.cnet.com/reviews/promise-pegasus-r6-review/](https://www.cnet.com/reviews/promise-pegasus-r6-review/)

Mine came with 24T (6x4T drives), and I wanted to quickly write a bash script to see what state the drives were in.  It actually benches nicely better than cnet said it did by the power of ```dd if=/dev/zero of=test.dat bs=1024k count=10000```

![me](https://github.com/DrCuff/smart/blob/main/bench.png)
## I vibe coded.  Biggly.  Much vibe.  All of the vibe.

I also crashed every LLM I tried. Turns out the disks were mostly fine. There's still some off by 1024 going on here that I'll diagnose at some point. This folks. This is the result:

864 lines of bash and awk that appear to be mostly correct, the output is groovy:

```
asciinema rec --overwrite smart.asc
asciinema convert --overwrite -f asciicast-v2 smart.asc smart.cast
agg smart.cast smart.gif
```


![me](https://github.com/DrCuff/smart/blob/main/smart.gif)
