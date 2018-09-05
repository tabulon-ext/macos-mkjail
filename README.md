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
| tar           | Extra\*\*  |

<small>
\*: The script will continue even if this utility isn't compiled properly  
\*\*: Upcoming
</small>
