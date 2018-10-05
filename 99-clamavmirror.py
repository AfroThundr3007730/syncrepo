#!/usr/bin/env python
# -*- coding: utf-8 -*-
# clamavmirror.py
# Copyright (C) 2015  Andrew Colin Kissa <andrew@topdog.za.net>
# vim: ai ts=4 sts=4 et sw=4
"""ClamAV Signature Mirroring Tool

Why
---

The existing clamdownloader.pl script does not have any error
correction it simply bails out if a downloaded file is not
valid and is unable to retry different mirrors if one fails.

This script will retry if a download fails with an http code
that is not 404, it will connect to another mirror if retries
fail or file not found or if the downloaded file is invalid.

It has options to set the locations for the working and
mirror directory as well as user/group ownership for the
downloaded files. It uses locking to prevent multiple
instances from running at the same time.

Requirements
------------

DNS-Python module - http://www.dnspython.org/

Usage
-----

$ ./clamavmirror.py -h
Usage: clamavmirror.py [options]

Options:
  -h, --help            show this help message and exit
  -a HOSTNAME, --hostname=HOSTNAME
                        ClamAV source server hostname
  -r TXTRECORD, --text-record=TXTRECORD
                        ClamAV Updates TXT record
  -w WORKDIR, --work-directory=WORKDIR
                        Working directory
  -d MIRRORDIR, --mirror-directory=MIRRORDIR
                        The mirror directory
  -u USER, --user=USER  Change file owner to this user
  -g GROUP, --group=GROUP
                        Change file group to this group
  -l LOCKDIR, --locks-directory=LOCKDIR
                        Lock files directory

Example Usage
-------------

mkdir /tmp/clamav/{lock,mirror,tmp}
./clamavmirror.py \
  -l /tmp/clamav/lock \
  -d /tmp/clamav/mirror \
  -w /tmp/clamav/tmp \
  -a db.za.clamav.net \
  -u nginx \
  -g nginx
"""
import os
import pwd
import grp
import sys
import time
import fcntl
import hashlib

from shutil import move
from optparse import OptionParser
from subprocess import PIPE, Popen

from dns.resolver import query, NXDOMAIN

if sys.version_info < (3, 0):
    from urllib2 import Request, URLError, urlopen
else:
    from urllib.request import Request
    from urllib.request import urlopen
    from urllib.error import URLError


def get_file_md5(filename):
    """Get a file's MD5"""
    if os.path.exists(filename):
        blocksize = 65536
        try:
            hasher = hashlib.md5()
        except ValueError:
            hasher = hashlib.new('md5', usedforsecurity=False)
        with open(filename, 'rb') as afile:
            buf = afile.read(blocksize)
            while len(buf) > 0:
                hasher.update(buf)
                buf = afile.read(blocksize)
        return hasher.hexdigest()
    else:
        return ''


def get_md5(string):
    """Get a string's MD5"""
    try:
        hasher = hashlib.md5()
    except ValueError:
        hasher = hashlib.new('md5', usedforsecurity=False)
    hasher.update(string.encode())
    return hasher.hexdigest()


def chunk_report(bytes_so_far, total_size):
    """Display progress"""
    percent = float(bytes_so_far) / total_size
    percent = round(percent * 100, 2)
    sys.stdout.write(
        "[x] Downloaded %d of %d bytes (%0.2f%%)\r" %
        (bytes_so_far, total_size, percent))
    if bytes_so_far >= total_size:
        sys.stdout.write('\n')


def chunk_read(response, handle, chunk_size=8192, report_hook=None):
    """Read chunks"""
    total_size = int(response.info().get('Content-Length'))
    bytes_so_far = 0
    while 1:
        chunk = response.read(chunk_size)
        handle.write(chunk)
        bytes_so_far += len(chunk)
        if not chunk:
            handle.close()
            break
        if report_hook:
            report_hook(bytes_so_far, total_size)
    return bytes_so_far


def error(msg):
    """print to stderr"""
    sys.stderr.write(msg + "\n")


def info(msg):
    """print to stdout"""
    print(msg)


def deploy_signature(source, dest, user=None, group=None):
    """Deploy a signature fole"""
    move(source, dest)
    os.chmod(dest, 0o644)
    if user and group:
        try:
            uid = pwd.getpwnam(user).pw_uid
            gid = grp.getgrnam(group).gr_gid
            os.chown(dest, uid, gid)
        except (KeyError, OSError):
            pass


def create_file(name, content):
    "Generic to write file"
    with open(name, 'w') as writefile:
        writefile.write(content)


def get_ip_addresses(hostname):
    """Return ip addresses from hostname"""
    try:
        answers = query(hostname, 'A')
        return [rdata.address for rdata in answers]
    except NXDOMAIN:
        return []


def get_txt_record(hostname):
    """Get the text record"""
    try:
        answers = query(hostname, 'TXT')
        return answers[0].strings[0].decode()
    except (IndexError, NXDOMAIN):
        return ''


def get_local_version(sigdir, sig):
    """Get the local version of a signature"""
    version = None
    filename = os.path.join(sigdir, '%s.cvd' % sig)
    if os.path.exists(filename):
        cmd = ['sigtool', '-i', filename]
        sigtool = Popen(cmd, stdout=PIPE, stderr=PIPE)
        while True:
            line = sigtool.stdout.readline().decode()
            if line:
                if line.startswith('Version:'):
                    version = line.split()[1].rstrip()
                    break
            else:
                break
        sigtool.wait()
    return version


def verify_sigfile(sigdir, sig):
    """Verify a signature file"""
    cmd = ['sigtool', '-i', '%s/%s.cvd' % (sigdir, sig)]
    sigtool = Popen(cmd, stdout=PIPE, stderr=PIPE)
    ret_val = sigtool.wait()
    return ret_val == 0


def download_sig(opts, ips, sig, version=None):
    """Download signature for IP list"""
    code = None
    downloaded = False
    for ipaddr in ips:
        try:
            if version:
                url = 'http://%s/%s.cvd' % (ipaddr, sig)
                filename = os.path.join(opts.workdir, '%s.cvd' % sig)
            else:
                url = 'http://%s/%s.cdiff' % (ipaddr, sig)
                filename = os.path.join(opts.workdir, '%s.cdiff' % sig)
            req = Request(url)
            req.add_header('Host', opts.hostname)
            response = urlopen(req)
            code = response.getcode()
            handle = open(filename, 'wb')
            chunk_read(response, handle, report_hook=chunk_report)
            if version:
                if (
                        verify_sigfile(opts.workdir, sig) and
                        version == get_local_version(opts.workdir, sig)):
                    downloaded = True
                    break
            else:
                downloaded = True
                break
        except URLError as err:
            if hasattr(err, 'code'):
                code = err.code
            continue
        finally:
            if 'handle' in locals():
                handle.close()
    return downloaded, code


def get_addrs(hostname):
    """get addrs"""
    count = 1
    for passno in range(1, 6):
        count = passno
        info("[+] Resolving hostname: %s pass: %d" % (hostname, passno))
        addrs = get_ip_addresses(hostname)
        if addrs:
            info("=> Resolved to: %s" % ','.join(addrs))
            break
        else:
            info("=> Resolution failed, sleeping 5 secs")
            time.sleep(5)
    if not addrs:
        error(
            "=> Resolving hostname: %s failed after %d tries" %
            (hostname, count))
        sys.exit(2)
    return addrs


def get_record(opts):
    """Get record"""
    count = 1
    for passno in range(1, 5):
        count = passno
        info("[+] Querying TXT record: %s pass: %s" % (opts.txtrecord, passno))
        record = get_txt_record(opts.txtrecord)
        if record:
            info("=> Query returned: %s" % record)
            break
        else:
            info("=> Txt record query failed, sleeping 5 secs")
            time.sleep(5)
    if not record:
        error("=> Txt record query failed after %d tries" % count)
        sys.exit(3)
    return record


def copy_sig(sig, opts, isdiff):
    """Deploy a sig"""
    info("Deploying signature: %s" % sig)
    if isdiff:
        sourcefile = os.path.join(opts.workdir, '%s.cdiff' % sig)
        destfile = os.path.join(opts.mirrordir, '%s.cdiff' % sig)
    else:
        sourcefile = os.path.join(opts.workdir, '%s.cvd' % sig)
        destfile = os.path.join(opts.mirrordir, '%s.cvd' % sig)
    deploy_signature(sourcefile, destfile, opts.user, opts.group)
    info("=> Deployed signature: %s" % sig)


def update_sig(options, addrs, sign, vers):
    """update signature"""
    info("[+] Checking signature version: %s" % sign)
    localver = get_local_version(options.mirrordir, sign)
    remotever = vers[sign]
    if localver is None or (localver and int(localver) < int(remotever)):
        info("=> Update required L: %s => R: %s" % (localver, remotever))
        for passno in range(1, 6):
            info("=> Downloading signature: %s pass: %d" % (sign, passno))
            status, code = download_sig(options, addrs, sign, remotever)
            if status:
                info("=> Downloaded signature: %s" % sign)
                copy_sig(sign, options, 0)
                break
            else:
                if code == 404:
                    error("=> Signature: %s not found, will not retry" % sign)
                    break
                error(
                    "=> Download failed: %s pass: %d, sleeping 5sec" %
                    (sign, passno))
                time.sleep(5)
    else:
        info("=> No update required L: %s => R: %s" % (localver, remotever))


def update_diff(opts, addrs, sig):
    """Update diff"""
    for passno in range(1, 6):
        info("[+] Downloading cdiff: %s pass: %d" % (sig, passno))
        status, code = download_sig(opts, addrs, sig)
        if status:
            info("=> Downloaded cdiff: %s" % sig)
            copy_sig(sig, opts, 1)
            break
        else:
            if code == 404:
                error("=> Signature: %s not found, will not retry" % sig)
                break
            error(
                "=> Download failed: %s pass: %d, sleeping 5sec" %
                (sig, passno))
            time.sleep(5)


def create_dns_file(opts, record):
    """Create the DNS record file"""
    info("[+] Updating dns.txt file")
    filename = os.path.join(opts.mirrordir, 'dns.txt')
    localmd5 = get_file_md5(filename)
    remotemd5 = get_md5(record)
    if localmd5 != remotemd5:
        create_file(filename, record)
        info("=> dns.txt file updated")
    else:
        info("=> No update required L: %s => R: %s" % (localmd5, remotemd5))


def main(options):
    """The main functions"""
    addrs = get_addrs(options.hostname)
    record = get_record(options)
    record_list = record.split(':')
    versions = {
        'main': record_list[1],
        'daily': record_list[2],
        'safebrowsing': record_list[6],
        'bytecode': record_list[7]
    }
    for signature_type in versions.keys():
        if signature_type in [i for i in versions.keys() if i != 'main']:
            # download diffs
            localver = get_local_version(options.mirrordir, signature_type)
            remotever = versions[signature_type]
            if localver is not None:
                for num in range(int(localver), int(remotever) + 1):
                    sig_diff = '%s-%d' % (signature_type, num)
                    filename = os.path.join(
                        options.mirrordir, '%s.cdiff' % sig_diff)
                    if not os.path.exists(filename):
                        update_diff(options, addrs, sig_diff)
        update_sig(options, addrs, signature_type, versions)
    create_dns_file(options, record)
    sys.exit(0)


if __name__ == '__main__':
    PARSER = OptionParser()
    PARSER.add_option(
        '-a', '--hostname',
        help='ClamAV source server hostname',
        dest='hostname',
        type='str',
        default='database.clamav.net')
    PARSER.add_option(
        '-r', '--text-record',
        help='ClamAV Updates TXT record',
        dest='txtrecord',
        type='str',
        default='current.cvd.clamav.net')
    PARSER.add_option(
        '-w', '--work-directory',
        help='Working directory',
        dest='workdir',
        type='str',
        default='/var/spool/clamav-mirror')
    PARSER.add_option(
        '-d', '--mirror-directory',
        help='The mirror directory',
        dest='mirrordir',
        type='str',
        default='/srv/www/datafeeds.baruwa.com/clamav')
    PARSER.add_option(
        '-u', '--user',
        help='Change file owner to this user',
        dest='user',
        type='str',
        default='nginx')
    PARSER.add_option(
        '-g', '--group',
        help='Change file group to this group',
        dest='group',
        type='str',
        default='nginx')
    PARSER.add_option(
        '-l', '--locks-directory',
        help='Lock files directory',
        dest='lockdir',
        type='str',
        default='/var/lock/subsys')
    OPTIONS, _ = PARSER.parse_args()
    try:
        LOCKFILE = os.path.join(OPTIONS.lockdir, 'clamavmirror')
        with open(LOCKFILE, 'w+') as lock:
            fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            main(OPTIONS)
    except IOError:
        info("=> Another instance is already running")
        sys.exit(254)
