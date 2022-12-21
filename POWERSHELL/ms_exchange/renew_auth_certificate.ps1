New-ExchangeCertificate -KeySize 2048 -PrivateKeyExportable $true -SubjectName "cn=Microsoft Exchange Server Auth Certificate" -DomainName "*.eine.firma.local" -FriendlyName "Microsoft Exchange Server Auth Certificate" -Services SMTP

Set-AuthConfig -NewCertificateThumbprint 3C98EE4581E1EE817996603EC34B163CEAFB2D6A -NewCertificateEffectiveDate (get-date)

Set-AuthConfig -PublishCertificate

Set-AuthConfig -ClearPreviousCertificate

IISRESET