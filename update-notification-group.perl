#!/usr/bin/env perl

use Scripts::Base -minimal;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::JSON qw/encode_json decode_json/;
use List::Util qw/any/;

my $filename = 'depts.json';
my %dept;
if (open my $fh, '<', $filename) {
    %dept = %{ decode_json join '', <$fh> };
}

my $ua = Mojo::UserAgent->new(max_redirects => 5);
$ua->transactor->name('Mozilla/5.0 (Windows NT 10.0; WOW64; rv:56.0) Gecko/20100101 Firefox/56.0');

# 爬学院代号
# 看上去医学院有两个代号
my $codesPage = utf8 $ua->get('http://xk.urp.seu.edu.cn/jw_service/service/academyClassLook.action')
    ->result->body;
my %codes;
while ($codesPage =~ />\[(\d+)\]([^<]+)/g) {
    my ($code, $name) = ($1, $2);
    $codes{$name} //= [];
    push @{$codes{$name}}, $code;
}

# 爬学院首页地址
my $data = utf8 $ua->get('http://www.seu.edu.cn/17399/list.htm')->result->body;
my $dom = Mojo::DOM->new($data);
for (@{$dom->find('#wp_content_w6_0 ul a')}) {
    my $url = $_->attr('href');
    my ($short) = $url =~ m{//([a-z0-9]+)\.seu\.edu\.cn};
    my $name = $_->text or next; # 不要没名字的
    $dept{$short} //= {};
    $dept{$short}{name} = $name;
    $dept{$short}{infoUrl} = $url;
    $dept{$short}{baseUrl} = $url =~ s{(?<![/:])/.*}{}r;
    $dept{$short}{codes} = $codes{$name};
}


for (sort { $dept{$a}{codes}[0] <=> $dept{$b}{codes}[0] } keys %dept) {
    say term "Short: ".$_."\nName: ".$dept{$_}{name}."\nCode: ".(join ', ', @{$dept{$_}{codes}})."\nWeb: ".$dept{$_}{infoUrl};
    my $res = eval { $ua->get($dept{$_}{infoUrl})->result };
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
                and $_->text =~ /(?:通知|公告|新闻|news|信息|更新|最新|快讯|学术|工作)/i
                and $_->text !~ /图/i
                and $_->text ne '信息门户'
         });
    if (not @$found) {
        say term "没有找到`通知公告'";
        next;
    }
    $dept{$_}{list} = [];
    my %a = ();
  ITEM:
    for my $notify (@$found) {
        my $text = $notify->text =~ s/\s//rg;
        my $p = $notify;
        print term $text.': ';
        my $id;
        for (1..9) {
            $p = $p->parent;
            my $list = $p->find('div[id]');
            for (@$list) {
                say term "Id: ".$_->attr('id');
                $id = $_->attr('id');
            }
            if (@$list) {
                last;
            }
        }
        if (!$id) {
            say term "找不到对应的新闻表格 id";
            next;
        }
        my $sel = '#'.$id;
        if (any { $sel eq $_->[0] } @{$dept{$_}{list}}) { # 有过这个id了
            say term "重复，跳过";
            next;
        }
        my $np = $notify;
        for (1..3) {
            $np = $np->parent;
            if ($np->tag eq 'li') {
                say term "不是新闻，跳过";
                next ITEM;
            }
        }
        push @{$dept{$_}{list}}, [$sel, $text];
    }
}

my $j = encode_json \%dept;
open my $file, '>', 'depts.json' or die term "打不开文件: $!\n";
binmode $file, ':unix';
say $file $j;
close $file;

