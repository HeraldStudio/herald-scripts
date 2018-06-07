#!/usr/bin/env perl

use Scripts::Base -minimal;
use Mojo::UserAgent;
use Mojo::DOM;
use Encode;
use Encode::Guess;
use IO::Handle ();

my $ua = Mojo::UserAgent->new;
mkdir 'result';
=comment
        my $dom = $res->dom;
        my @classes = @{ $dom->find('#dgData > tbody > tr') };
        shift @classes;
        my @classInfo = map {; $_->find('td')->map(sub { trim shift->all_text; }) } @classes;
        for (@classInfo) {
            my ($name, $courseId, $courseName, $hours)
        }
=cut
STDOUT->autoflush(1);
sub trim
{
    my $text = shift;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $text;
}

# Graduate's timetable
{
    my $res = $ua->get('http://121.248.63.139/nstudent/pygl/kbcx_yx.aspx')->result;
    my $dom = $res->dom;
    my %form = map {; $_->attr('name') => $_->attr('value') } @{$dom->find('input')};
    my @depts = ("000","001","002","003","004","005","006","007","008","009","010","011","012","014","016","017","018","019","021","022","025","040","042","044","055","080","081","084","086","101","110","111","301","316","317","318","319","401","403","404","990","997");
  DEPT:
    for my $dept (@depts) {
        print term "Grad ${dept}...";
        my $text;
      TRY:
        for (1..3) {
            my $res = $ua->post('http://121.248.63.139/nstudent/pygl/kbcx_yx.aspx',
                                form => { %form, drpyx => $dept })->result;
            if ($res->is_success) {
                $text = $res->body;
                last TRY;
            }
        }
        if (! $text) {
            say term 'Fail';
            next DEPT;
        }
        
        open my $file, '>', 'result/grad-'.$dept;
        binmode $file, ':unix';
        print $file decode(Guess => $text);
        close $file;
        say term 'Done';
    }
    
}
# Undergraduate's timetable
{
    my $res = $ua->get('http://xk.urp.seu.edu.cn/jw_service/service/academyClassLook.action')->result;
    my $decodedBody = decode(Guess => $res->body);
    my $dom = Mojo::DOM->new($decodedBody);
    my %links = map {; (trim $_->all_text) => 'http://xk.urp.seu.edu.cn/jw_service/service/' . $_->attr('href') } @{ $dom->find('.FrameItemFont a') };
  DEPT:
    for my $dept (keys %links) {
        my $link = $links{$dept};
        print term "Undergrad ${dept}...";
        my $text;
      TRY:
        for (1..3) {
            my $res = $ua->get($link)->result;
            if ($res->is_success) {
                $text = $res->body;
                last TRY;
            }
        }
        if (! $text) {
            say term 'Fail';
            next DEPT;
        }
        my $decodedBody = decode(Guess => $text);
        my ($code) = $dept =~ /\[(\d+)\]/;
        open my $file, '>', 'result/ug-'.$code;
        binmode $file, ':unix';
        print $file $decodedBody;
        close $file;
        say term 'Done';
    }
}
