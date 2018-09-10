# macOS mkjail
Script to automatically prepare a functional chroot jail with the following utilities:

| Utility       | Priority    | Type            |
|:--------------|:-----------:|:---------------:|
| GNU Bash      | Required    | Source code     |
| GNU coreutils | Required    | Source code     |
| GNU inetutils | Required\*  | Source code     |
| grep          | Extra       | Source code     |
| less          | Extra       | Source code     |
| make          | Extra       | Source code     |
| nano          | Extra       | Source code     |
| gzip          | Extra       | Source code     |
| zsh           | Extra       | Source code     |
| tar           | Extra       | Source code     |
| binutils      | Extra       | Source code     |
| xz-utils      | Extra       | Source code     |
| bzip2\*\*     | Extra       | Precompiled\*\* |
| bashpm\*\*    | Recommended | Bash Script\*\* |

\*: The script will continue even if this utility isn't compiled properly  
\*\*: Upcoming  

**Note:** You don't need utility-archive to use this script. It is there just in case the official source goes down.
  
[Original gist](https://gist.github.com/pixelomer/f29eedb34368bec62df545c05db706b4)