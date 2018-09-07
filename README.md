# macOS mkjail
Script to automatically prepare a functional chroot jail with the following utilities:

| Utility       | Type       |
|:-------------:|:----------:|
| GNU Bash      | Required   |
| GNU coreutils | Required   |
| GNU inetutils | Required\* |
| grep          | Extra      |
| less          | Extra      |
| make          | Extra      |
| nano          | Extra      |
| gzip          | Extra      |
| zsh           | Extra      |
| tar           | Extra      |

\*: The script will continue even if this utility isn't compiled properly  
\*\*: Upcoming  

**Note:** You don't need utility-archive to use this script. It is there just in case the official source goes down.
  
[Original gist](https://gist.github.com/pixelomer/f29eedb34368bec62df545c05db706b4)