DTDPARSE=dtdparse
DTDPARSE_FLAGS=--declaration sgmldecl --nounexpanded
RUBY19=ruby

all: ruby

ruby: dtdparse
	${RUBY19} dtdxmlt2json.rb

dtdparse: strict.dtd.xml loose.dtd.xml frameset.dtd.xml

strict.dtd.xml:	strict.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} strict.dtd > strict.dtd.xml	

loose.dtd.xml: loose.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} loose.dtd > loose.dtd.xml

frameset.dtd.xml: frameset.dtd
	${DTDPARSE} ${DTDPARSE_FLAGS} frameset.dtd > frameset.dtd.xml
