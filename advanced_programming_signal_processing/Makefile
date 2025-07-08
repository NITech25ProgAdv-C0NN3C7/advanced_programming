all: matching feature_matchings

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

	gcc -w -Ofast -o matching main.c imageUtil.c -lm -march=native -mfpmath=both -fopenmp

feature_matchings: feature_matchings.cpp
	g++ -std=c++17 -O2 -o $@ $< `pkg-config --cflags --libs opencv4`

.PHONY: clean clean_subfile

clean:
	$(RM) matching
	$(RM) feature_matchings

clean_subfile:
	$(RM) imgproc/*.ppm
	$(RM) result/*.txt
	$(RM) result/*.ppm
