(Check the [Ml2json website](http://ml2json.christianjaeger.ch/) for
properly formatted versions of these documents.)

---

Help text
---------

Run `./ml2json --help`.

Instructions
------------

1. collect all mbox files your archive is comprised of into one
directory (or directory tree, if you use the `--recurse` option)

2. decide upon a base directory where all the unpacked attachments (as
well as serialized state--for details see [[phases]]) should be
stored; if you don't care about accessing the attachments, some
directory under `/tmp` will be choosen. ml2json will create a symlink
at `~/.ml2json-tmp` which points to that generated directory, so that
subsequent runs of ml2json will find it again and can omit part of the
work that was already done. If you *do* care about the generated
attachments, specify the `--attachment-basedir` option.

3. it's possible to customize what fields are output in the JSON by
using a config file. You can also put most commandline parameters into
a config file, thus if you want to run a particular conversion
repeatedly and consistently, consider doing that. The file
[default_config.pl](https://github.com/pflanze/ml2json/blob/master/default_config.pl)
has the defaults; this file is not meant
to be edited, instead, create a new file that shadows the config keys
that you want to set, then pass the path to it to the `--config`
option. An example can be found in
[ml2json-list-generate/config.pl](https://github.com/pflanze/ml2json/blob/master/ml2json-list-generate/config.pl)
which is used to generate the [list archive](//mailing_list.md).
Read about `--config` in `./mk2json --help`.

4. run `./mk2json sourcedir --json-to targetfile`, perhaps with the
additional options of your choice (in particular you need to use the
`--mbox-glob` option, if the files are not named according to the
default mbox glob pattern, `*.mbox`; use `*` to make it look at all
files).

5. the temp / attachments dir is structured as follows:

        $attachment_basedir/$md5_of_mbox_path/$n/<files>

 `$md5_of_mbox_path` is `md5(mbox_path)`; this to shorten down the path to
 something that won't ever conflict. This is not to hide the original
 path: it's both possible to determine the original path by using md5
 hash crackers, and if the `$attachment_basedir/$md5_of_mbox_path/__meta`
 file is still present, it contains the path.

 If the `cache_dir` option is set, then no __meta files will be
 created within `$attachment_basedir` (making it possible to use it
 cleanly for serving in public html archives).

 If you want to know which mbox path a particular md5 originated from,
 use the ml2json `--show-mbox-path` option.

 `$n` is the non-negative integer number of the position of the email
 in the mbox, or `$o-$p` in case of ezmlm archive dirs, where $o is
 the ezmlm subdir and $p the message file name within the subdir (both
 being non-negative integers, $p possibly with a leading zero).

 You can run `ml2json --deidentify "$md5_of_mbox_path/$n"` to make it
 print the original message string (as it was cut out of the mbox file).

6. optionally, to clean up the generated temporary / attachments
files, run ml2json with the `--cleanup` option; if you gave the
`--attachment-basedir` option before, it has to be given again,
otherwise ml2json will just look at `~/.ml2json-tmp` (or do nothing if
not present).
