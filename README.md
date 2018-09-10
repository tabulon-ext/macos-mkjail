# macOS mkjail
Script to automatically prepare a functional chroot jail with the following utilities:

| Utility | Priority | Type |
|:----|:---:|:---:|
| [bash](https://www.gnu.org/s/bash) | Required | Source code |
| [coreutils](https://www.gnu.org/software/coreutils/coreutils.html) | Required | Source code |
| [inetutils](https://www.gnu.org/software/inetutils/) | Required\* | Source code |
| [grep](https://www.gnu.org/software/grep/) | Extra | Source code |
| [less](https://www.gnu.org/software/less/) | Extra | Source code |
| [make](https://www.gnu.org/s/make) | Extra | Source code |
| [nano](https://www.nano-editor.org) | Extra | Source code |
| [gzip](https://www.gnu.org/software/gzip/) | Extra | Source code |
| [zsh](http://zsh.sourceforge.net) | Extra | Source code |
| [tar](https://www.gnu.org/software/tar/) | Extra | Source code |
| [binutils](https://www.gnu.org/software/binutils/) | Extra | Source code |
| [xz-utils](https://tukaani.org/xz/) | Extra | Source code |
| [bzip2](https://web.archive.org/web/20180801004107/http://www.bzip.org)\*\* | Extra | Precompiled\*\* |
| [bashpm](https://github.com/pixelomer/bashpm)\*\* | Recommended | Bash Script\*\* |

\*: The script will continue even if this utility isn't compiled properly  
\*\*: Upcoming  

**Note:** You don't need utility-archive to use this script. It is there just in case the official source goes down.
  
[Original gist](https://gist.github.com/pixelomer/f29eedb34368bec62df545c05db706b4)