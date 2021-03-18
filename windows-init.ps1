Install-Module -Name WinGet
winget install powertoys
winget install voidtools.Everything
winget install Tencent.wechat
winget install Qv2ray.Qv2ray

# install oh my posh 
Install-Module posh-git -Scope CurrentUser
Install-Module oh-my-posh -Scope CurrentUser
Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
echo "Import-Module posh-git" >> $profile
echo "Import-Module oh-my-posh" >> $profile
# install font https://github.com/microsoft/cascadia-code/releases
# tutorial https://docs.microsoft.com/en-us/windows/terminal/tutorials/powerline-setup