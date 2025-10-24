#!/usr/bin/env perl
use 5.036;
use utf8;
use warnings 'all';
use autodie ':all';
use open qw/:std :utf8/;
utf8::decode($_) for @ARGV;

use Mojolicious::Lite -async_await;
use Mojo::URL;
use Mojo::Util;
use Mojo::Headers;
use DDP;

any '/*' => sub ($c) {
    my $req = $c->req;
    my $parts = $req->url->path;
    my @parts = split '/', $parts;
    shift @parts until $parts[0];

    my @deletion;
    my @insertion;

    my $next_hop;
    my $is_drop_all = 0;

    while (@parts) {
        my $cmd = shift @parts;
        if ($cmd eq '_drop') {
            my $param = Mojo::Util::url_unescape shift @parts;
            if ($param eq '_all') {
                $is_drop_all = 1;
            } else {
                push @deletion, $param;
            }
        } elsif ($cmd eq '_url') {
            $next_hop = join '/', @parts;
            last;
        } else {
            my $param = Mojo::Util::url_unescape shift @parts;
            push @insertion, [ $cmd, $param ];
        }
    }

    my $headers = $is_drop_all ? Mojo::Headers->new : $req->headers;

    for my $deletion (@deletion) {
        $headers->remove($deletion);
    }
    for my $insertion (@insertion) {
        $headers->header(@$insertion);
    }

    my $onward_tx = $c->ua->build_tx(
        $req->method,
        $next_hop => $headers->to_hash,
        $req->body,
    );

    $c->proxy->start_p($onward_tx);
};

app->start;
