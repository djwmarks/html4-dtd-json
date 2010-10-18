DTDPARSE=dtdparse
DTDPARSE_FLAGS=--declaration sgmldecl --nounexpanded
RUBY19=ruby

all: json

json: strict.json loose.json frameset.json

strict.json: strict.dtd.xml dtdxml2json.rb
	${RUBY19} dtdxml2json.rb strict.dtd.xml > strict.json

loose.json: loose.dtd.xml dtdxml2json.rb
	${RUBY19} dtdxml2json.rb loose.dtd.xml > loose.json

frameset.json: frameset.dtd.xml dtdxml2json.rb
	${RUBY19} dtdxml2json.rb frameset.dtd.xml > frameset.json

dtdparse: strict.dtd.xml loose.dtd.xml frameset.dtd.xml

strict.dtd.xml:	strict.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} strict.dtd > strict.dtd.xml	

loose.dtd.xml: loose.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} loose.dtd > loose.dtd.xml

frameset.dtd.xml: frameset.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} frameset.dtd > frameset.dtd.xml
