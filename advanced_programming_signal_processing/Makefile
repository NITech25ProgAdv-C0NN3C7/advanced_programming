matching: main.c imageUtil.c
#	gcc -w -o matching main.c imageUtil.c -lm
#	gcc -w -O1 -o matching main.c imageUtil.c -lm
#	gcc -w -O2 -o matching main.c imageUtil.c -lm
#	gcc -w -O3 -o matching main.c imageUtil.c -lm
#	gcc -w -O3 -o matching main.c imageUtil.c -lm -funroll-all-loops -funroll-loops -funsafe-loop-optimizations
#	gcc -w -O3 -o matching main.c imageUtil.c -lm -mtune=native
#	gcc -w -Ofast -o matching main.c imageUtil.c -lm -mtune=native -mfpmath=both
#	icc -w -fast -o matching main.c imageUtil.c -lm -mtune=native
#	icc -w -fast -o matching main.c imageUtil.c -lm

	gcc -w -Ofast -o matching main.c imageUtil.c -lm -march=native -mfpmath=both

clean:
	$(RM) matching
