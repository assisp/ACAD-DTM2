VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} UserForm1 
   Caption         =   "Criar TIN"
   ClientHeight    =   5040
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   5430
   OleObjectBlob   =   "UserForm1.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "UserForm1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False


Public myDTM As New clsDTM

Rem ---
Rem --- Initialization
Rem ---
Private Sub UserForm_Initialize()
    Dim mystep As Double
    
    CommandButton2.BackColor = myDTM.getRGBColor(myDTM.TINColor)
    CommandButton3.BackColor = myDTM.getRGBColor(myDTM.CNPColor)
    CommandButton5.BackColor = myDTM.getRGBColor(myDTM.CNSColor)
    
    For mystep = 1 To 5# Step 1
        ComboBox1.AddItem (CStr(mystep))
    Next mystep
    
    For mystep = 0.1 To 5# Step 0.1
        ComboBox2.AddItem (CStr(mystep))
    Next mystep
    
    ComboBox1.ListIndex = 0
    ComboBox2.ListIndex = 4
    
    TextBox1.Text = myDTM.TINLayer
    TextBox3.Text = myDTM.CNPLayer
    TextBox4.Text = myDTM.CNSLayer
    TextBox5.Text = 40
    
End Sub

Rem ---
Rem --- Generate
Rem ---
Private Sub CommandButton1_Click()
    'Module1.LoadPoints ComboBox1.Text, TextBox1.Text
    Dim CNPStep As Double
    Dim CNSStep As Double
    Dim a As Double
    Dim b As Double
    
    If CheckBox1.Value = True Then
        If IsNumeric(ComboBox1.Value) Then
            CNPStep = CDbl(ComboBox1.Value)
        Else
            MsgBox "The value for main contour lines spacing must be numeric"
            Exit Sub
        End If
        
        If IsNumeric(ComboBox2.Value) Then
            CNSStep = CDbl(ComboBox2.Value)
        Else
            MsgBox "The value for secondary contour lines spacing must be numeric"
            Exit Sub
        End If
        
        a = CNPStep / CNSStep
        b = Int(a) + Fuzz
        If a > b Then
            MsgBox "The value for the main contour lines spacing must be a multiple of the secondary contour lines spacing " & a & " > " & b
            Exit Sub
        End If
    End If
    
    UserForm1.Hide
    myDTM.CNPLayer = TextBox3.Text
    myDTM.CNSLayer = TextBox4.Text
    myDTM.TINLayer = TextBox1.Text
    
    myDTM.createTIN (CDbl(TextBox5.Text))
    If CheckBox1.Value = True Then
        myDTM.createCN CDbl(ComboBox1.Value), CDbl(ComboBox2.Value)
    End If
    
    End
End Sub

Rem ---
Rem --- TIN Layer Color
Rem ---
Private Sub CommandButton2_Click()
    Dim cecolor As Variant
    
    cecolor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SendCommand ("_color" & vbCr)
    myDTM.TINColor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SetVariable "CECOLOR", cecolor
    
    
    'MsgBox "Selected color " & myDTM.TINColor
    CommandButton2.BackColor = myDTM.getRGBColor(myDTM.TINColor)
End Sub

Rem ---
Rem --- CN Principal layer Color
Rem ---
Private Sub CommandButton3_Click()
    Dim cecolor As Variant
    
    cecolor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SendCommand ("_color" & vbCr)
    myDTM.CNPColor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SetVariable "CECOLOR", cecolor
    
    CommandButton3.BackColor = myDTM.getRGBColor(myDTM.CNPColor)
End Sub

Rem ---
Rem --- CN Secondary layer Color
Rem ---
Private Sub CommandButton5_Click()
    Dim cecolor As Variant
    
    cecolor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SendCommand ("_color" & vbCr)
    myDTM.CNSColor = ThisDrawing.GetVariable("CECOLOR")
    ThisDrawing.SetVariable "CECOLOR", cecolor
    
    CommandButton5.BackColor = myDTM.getRGBColor(myDTM.CNSColor)
End Sub

Rem ---
Rem --- Cancel
Rem ---
Private Sub CommandButton4_Click()
    End
End Sub

