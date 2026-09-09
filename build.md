Threads-Chiggi: 434.0.0.41.74  

Install [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases) for non-root Google APKs  
Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to detach patched apps from Play Store  

Repository: [Patched Apps](https://github.com/andrewliang25/patched-apps)  

Every APK/module is published with [GitHub build provenance attestations](https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) — verify a downloaded file with the [GitHub CLI](https://cli.github.com):  
```  
gh attestation verify <file> --repo andrewliang25/patched-apps  
```  
Patches: durgesh0505/chiggi_morphe_patches/patches-1.21.2.mpp  
[Changelog](https://github.com/durgesh0505/chiggi_morphe_patches/releases/tag/v1.21.2)

CLI: MorpheApp/morphe-cli/morphe-desktop-1.15.0-all.jar    
