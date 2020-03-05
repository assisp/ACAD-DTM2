Attribute VB_Name = "DTM"
Rem ---
Rem --- DTM Macros
Rem ---

Sub TIN()
    UserForm1.Show
End Sub

Sub CN()
    UserForm2.Show
End Sub

Sub ALIG()
    Dim DTM As clsDTM
    Set DTM = New clsDTM
    
    DTM.createALIG
End Sub

Sub VERT()
    Dim DTM As clsDTM
    Set DTM = New clsDTM
    
    DTM.createVERT
End Sub
