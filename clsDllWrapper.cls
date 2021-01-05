VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsDllWrapper"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private m_handle As LongPtr

Rem ------------------------------------------------------------------------------
Rem --- External DLL declarations
Rem ------------------------------------------------------------------------------
Private Declare PtrSafe Function DTMLib_init _
    Lib "DTM2.dll" () As LongPtr
    
Private Declare PtrSafe Sub DTMLib_close _
    Lib "DTM2.dll" (ByVal handle As Any)

Private Declare PtrSafe Function DTMLib_pointListSize _
    Lib "DTM2.dll" (ByVal handle As Any) As Long

Private Declare PtrSafe Function DTMLib_addPoint _
    Lib "DTM2.dll" ( _
        ByVal handle As Any, ByVal x As Double, ByVal y As Double, ByVal z As Double _
    ) As Long
Private Declare PtrSafe Function DTMLib_appendPoint _
    Lib "DTM2.dll" ( _
        ByVal handle As Any, ByVal x As Double, ByVal y As Double, ByVal z As Double _
    ) As Long

Private Declare PtrSafe Sub DTMLib_getPoint _
    Lib "DTM2.dll" ( _
        ByVal handle As Any, ByVal index As Long, ByRef x As Double, ByRef y As Double, ByRef z As Double _
    )
Private Declare PtrSafe Function DTMLib_addConstraint _
     Lib "DTM2.dll" ( _
        ByVal handle As Any, ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double _
     ) As Long
     
Private Declare PtrSafe Function DTMLib_triangulate _
    Lib "DTM2.dll" ( _
        ByVal handle As Any _
    ) As Long

Private Declare PtrSafe Function DTMLib_getTriangle _
    Lib "DTM2.dll" ( _
        ByVal handle As Any, ByVal index As Long, ByRef v1 As Double, ByRef v2 As Double, ByRef v3 As Double _
    ) As Boolean

Rem ---------------------------------------------------------------------------------
Rem --- Interface
Rem ---------------------------------------------------------------------------------

Private Sub Class_Initialize()
    m_handle = DTMLib_init
End Sub

Private Sub Class_Terminate()
    Call DTMLib_close(m_handle)
End Sub

Friend Function LibPointListSize() As Long
    LibPointListSize = DTMLib_pointListSize(m_handle)
End Function

Friend Function LibAddPoint(ByVal x As Double, ByVal y As Double, ByVal z As Double) As Long
    LibAddPoint = DTMLib_addPoint(m_handle, x, y, z)
End Function

Friend Function LibAppendPoint(ByVal x As Double, ByVal y As Double, ByVal z As Double) As Long
    LibAppendPoint = DTMLib_appendPoint(m_handle, x, y, z)
End Function

Friend Sub LibGetPoint(ByVal index As Long, ByRef x As Double, ByRef y As Double, ByRef z As Double)
    Call DTMLib_getPoint(m_handle, index, x, y, z)
End Sub

Friend Function LibAddConstraint(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double) As Long
    LibAddConstraint = DTMLib_addConstraint(m_handle, x1, y1, x2, y2)
End Function

Friend Function LibTriangulate() As Long
    LibTriangulate = DTMLib_triangulate(m_handle)
End Function

Friend Function LibGetTriangle(ByVal index As Long, ByRef v1 As Double, ByRef v2 As Double, ByRef v3 As Double) As Boolean
    LibGetTriangle = DTMLib_getTriangle(m_handle, index, v1, v2, v3)
End Function

