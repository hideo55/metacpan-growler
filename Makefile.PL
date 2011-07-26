use inc::Module::Install;

name "metacpan-growler";
all_from "metacpan-growler.pl";
install_script "metacpan-growler.pl";

requires 'Cocoa::Growl';
requires 'Cocoa::EventLoop';
requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'Data::MessagePack';
requires 'JSON';
requires 'Cache::LRU';

WriteAll;
