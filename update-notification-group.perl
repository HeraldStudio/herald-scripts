#!/usr/bin/env perl

use Scripts::Base -minimal;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::JSON qw/encode_json/;

my $ua = Mojo::UserAgent->new(max_redirects => 5);
$ua->transactor->name('Mozilla/5.0 (Windows NT 10.0; WOW64; rv:56.0) Gecko/20100101 Firefox/56.0');

# 爬学院代号
my $codesPage = utf8 $ua->get('http://xk.urp.seu.edu.cn/jw_service/service/academyClassLook.action')
    ->result->body;
my %codes = $codesPage =~ />\[(\d+)\]([^<]+)/g;
%codes = reverse %codes; # name => code

# 爬学院首页地址
my $data = utf8 $ua->get('http://www.seu.edu.cn/17399/list.htm')->result->body;
my $dom = Mojo::DOM->new($data);
my %dept = map {; $_->text,
                  { website => $_->attr('href') =~ s{/$}{}r,
                    code => $codes{$_->text} } }
@{$dom->find('#wp_content_w6_0 ul a')};

for (sort { $dept{$a}{code} <=> $dept{$b}{code} } keys %dept) {
    say term "Name: ".$_."\nCode: ".$dept{$_}{code}."\nWeb: ".$dept{$_}{website};
    my $res = eval { $ua->get($dept{$_}{website})->result };
    if ($@) {
        say term "连接失败: $@";
        next;
    } elsif (not $res->is_success) {
        say term '连接失败. Code: '.$res->code."\nMessage: ".$res->message;
        next;
    }
    my $data = utf8 $res->body;
    my $dom = Mojo::DOM->new($data);
    my $found = $dom->find('*')->grep
        (sub {
            length ($_->text =~ s/\s//rg) < 5
                and $_->text =~ /(?:通知|公告|新闻|news|信息|更新|最新|快讯)/i
                and $_->text !~ /图/i
         });
    if (not @$found) {
        say term "没有找到`通知公告'";
        next;
    }
    $dept{$_}{groups} = {};
    my %a = ();
    for my $notify (@$found) {
        my $text = $notify->text =~ s/\s//rg;
        my $addr;
        my $href;
        if ($notify->tag eq 'a') {
            $href = $notify->attr('href');
        } else {
            my $list = $notify->parent->parent->find('a');
            $list = $notify->parent->parent->parent->parent->find('.more a, .more_btn a, .more_text a') if not @$list;
            if (not @$list) {
                say term "找不到对应的链接: ".$notify->text;
                next;
            }
            $href = $list->[0]->attr('href');
        }
        $addr = $href =~ m{^https?://} ? $href
            : ($href =~ m{^/}
               ? $dept{$_}{website}.$href
               : $dept{$_}{website}.'/'.$href);
        next if $a{$addr};
        $a{$addr} = 1;
        say term "$text: $addr";
        $dept{$_}{groups}{$text} = $addr;
    }
}

my $j = encode_json \%dept;
open my $file, '>', 'depts.json' or die term "打不开文件: $!\n";
binmode $file, ':unix';
say $file $j;
close $file;

