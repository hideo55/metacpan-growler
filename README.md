This is MetaCPAN Growler: fetches MetaCPAN recent update modules and growls as new activies are coming in.

## INSTALLATION

 Just run github-growler.pl. You might need to install its CPAN module dependencies with cpan -i . command.

## CONFIGURATION

By default this scripts fetches the github updates every 300 seconds, displays at most 10 Growl notification per fetch and caches author information recent 100 authors and you can change the both settings with Mac OS X preferences:


    defaults write com.github.hideo55.metacpangrowler interval 300
    defaults write com.github.hideo55.metacpangrowler maxGrowls 10
    defaults write com.github.hideo55.metacpangrowler cacheSize 100

## AUTHOR

Hideaki Ohno
