# OpenComputerScripts

各种各样关于OC的代码

**在使用本仓库代码的过程中遇到技术性问题，可通过提交Issue或QQ(1362050620)反馈.**

[开放式电脑 OpenComputers](https://github.com/MightyPirates/OpenComputers) (以下简称OC)是MC的一个非常棒的mod.

开发者十分友好,社区非常和谐. 有问题可以直接提issue或者去irc和discord服务器上面对面交流(注意时差,主要开发人员当地半夜都不在线)

[在MC百科上查看OC](http://www.mcmod.cn/class/389.html)

[在Curseforge上查看OC](https://minecraft.curseforge.com/projects/opencomputers)

本仓库中代码还使用到了[Computronics](https://github.com/asiekierka/Computronics/tree/master/src/main/resources/assets/computronics/doc/opencomputers/computronics/en_US)和[OpenSecurity](https://github.com/PC-Logix/OpenSecurity/wiki).

一些可能有用的链接:

[Computronics官网](https://wiki.vexatos.com/wiki:computronics)

## 快速使用

首先搭建一台带有因特网卡的电脑并启动,打开[update.lua](update.lua)并复制全部内容,到游戏中输入`edit update`打开编辑器,用鼠标中键粘贴,按Ctrl+S保存,按Ctrl+W退出编辑器.然后输入`update`后,一些基本库将会被自动下载到本地. 注意如果在`/home`目录下保存失败,可输入`cd /tmp`切换到系统临时文件夹尝试,或在硬盘上安装openos后尝试 (或者找一个可写的介质即可).