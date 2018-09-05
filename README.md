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
| zsh           | Extra\*\*  |
| tar           | Extra\*\*  |

\*: The script will continue even if this utility isn't compiled properly  
\*\*: Upcoming
