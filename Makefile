po4a_config = po4a.cfg

translate:
	po4a ${po4a_config} --debug
.PHONY: translate

${po4a_config}: generate-po4a-config.sh original/*.md
	./$< > $@
