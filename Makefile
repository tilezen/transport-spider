INPUT_FILES=\
	input/berlin_friedrichstrasse.input \
	input/chatelet.input \
	input/gare_du_nord.input \
	input/penn_nyc.input \
	input/sacramento.input \
	input/u_bundestag.input \
	input/union_station_dc.input \
	input/union_station_la.input \
	input/castro_muni.input \
	input/camden_baltimore.input \
	input/paddington.input \
	input/paddington_tube.input \
	input/waterloo_1.input \
	input/waterloo_2.input \
	input/victoria_1.input \
	input/victoria_2.input \
	input/london_bridge.input \
	input/liverpool_street_1.input \
	input/liverpool_street_2.input \
	input/liverpool_street_3.input \
	input/kings_x_1.input \
	input/kings_x_2.input \
	input/euston_1.input \
	input/euston_2.input \
	input/marylebone.input \
	input/farringdon.input

DOT_FILES=$(patsubst input/%.input,output/%.dot,$(INPUT_FILES))
PDF_FILES=$(DOT_FILES:.dot=.dot.pdf)
PNG_FILES=$(DOT_FILES:.dot=.dot.png)
SVG_FILES=$(DOT_FILES:.dot=.dot.svg)

SPIDER_FLAGS=
ifneq "$(origin OVERPASS_URL)" "undefined"
  SPIDER_FLAGS+= --overpass-url=$(OVERPASS_URL)
endif

all: $(PDF_FILES) $(PNG_FILES) $(SVG_FILES)

clean:
	rm -f $(PDF_FILES) $(PNG_FILES) $(SVG_FILES) $(DOT_FILES)

.PRECIOUS: %.dot

output/%.dot: input/%.input spider.rb
	@mkdir -p output
	bundle exec ruby spider.rb $(SPIDER_FLAGS) `cat $<` > $@

%.dot.pdf: %.dot
	unflatten -l 3 $< > $(<).tmp && \
	dot -Tpdf -o $@ $(<).tmp && \
	rm -f $(<).tmp

%.dot.png: %.dot
	unflatten -l 3 $< > $(<).tmp && \
	dot -Tpng -Gsize=5.8,10\! -Gdpi=100 -o $@ $(<).tmp && \
	rm -f $(<).tmp

%.dot.svg: %.dot
	unflatten -l 3 $< > $(<).tmp && \
	dot -Tsvg -Gsize=5.8,10\! -o $@ $(<).tmp && \
	rm -f $(<).tmp
