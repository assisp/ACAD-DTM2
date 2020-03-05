VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsDTM"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False

Option Explicit

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
    
Rem -----------------------------------------------------------------------------------------------------------------------
Rem --- Internal Variables                                                                           ---
Rem -----------------------------------------------------------------------------------------------------------------------
Private Const ERR_EMPTY_VALUE         As Long = -2145320927
Private Const ERR_EMPTY_VALUE_ZCAD    As Long = -2145320928
Private Const ERR_COMMAND_CANCELED    As Long = -2145386183
Private Const ERR_GETVALUE_CANCELED   As Long = -2147352567
Private Const ERR_EMPTY_POINT         As Long = -2147467259

Private Const Fuzz As Double = 0.0001
Private Const PI As Double = 3.14159265358979
Private Const PI2 As Double = PI * 0.5
Private Const DEFAULT_CHARSET As Long = 1
Private Const DEFAULT_PITCH As Long = 0
    
Private myTINColor As Integer
Private myCNPColor  As Integer
Private myCNSColor  As Integer
Private myTINLayer As String
Private myCNPLayer  As String
Private myCNSLayer  As String

Private myTextHeight As Double
Private myVTextHeight As Double



Rem -----------------------------------------------------------------------------------------------------------------------
Rem --- CONSTRUCTORS / DESTRUCTORS                                                                    ---
Rem -----------------------------------------------------------------------------------------------------------------------
Private Sub Class_Initialize()
    myTINColor = 62  'light green
    myCNPColor = 22  'brown
    myCNSColor = 122 'light blue

    myTINLayer = "TIN"
    myCNPLayer = "CN-P"
    myCNSLayer = "CN-S"
    
    myTextHeight = 1
    myVTextHeight = 0.4
End Sub

Rem -----------------------------------------------------------------------------------------------------------------------
Private Sub Class_Terminate()
    
End Sub
Rem -----------------------------------------------------------------------------------------------------------------------
Rem --- CLASS GET/LET/SET PROPERTIES                                                                 ---
Rem -----------------------------------------------------------------------------------------------------------------------

Public Property Get TINColor() As Integer
    TINColor = myTINColor
End Property

Public Property Let TINColor(ByVal pValue As Integer)
    myTINColor = pValue
End Property

Public Property Get CNPColor() As Integer
    CNPColor = myCNPColor
End Property

Public Property Let CNPColor(ByVal pValue As Integer)
    myCNPColor = pValue
End Property

Public Property Get CNSColor() As Integer
    CNSColor = myCNSColor
End Property

Public Property Let CNSColor(ByVal pValue As Integer)
    myCNSColor = pValue
End Property

Public Property Get TINLayer() As String
    TINLayer = myTINLayer
End Property

Public Property Let TINLayer(ByVal pValue As String)
    myTINLayer = pValue
End Property

Public Property Get CNPLayer() As String
    CNPLayer = myCNPLayer
End Property

Public Property Let CNPLayer(ByVal pValue As String)
    myCNPLayer = pValue
End Property

Public Property Get CNSLayer() As String
    CNSLayer = myCNSLayer
End Property

Public Property Let CNSLayer(ByVal pValue As String)
    myCNSLayer = pValue
End Property

Rem -----------------------------------------------------------------------------------------------------------------------
Rem --- CLASS METHODS                                                                              ---
Rem -----------------------------------------------------------------------------------------------------------------------

Private Function getPath(pf As String) As String
    getPath = Left(pf, InStrRev(pf, "\") - 1)
End Function

Rem ---
Rem --- get RGB color from Acad colorindex
Rem ---
Public Function getRGBColor(colorind As Integer) As Long
    Dim color As New AcadAcCmColor
    color.ColorIndex = colorind
    
    getRGBColor = RGB(color.Red, color.Green, color.Blue)
End Function

Rem ---
Rem --- calculate distance between point p1 and p2
Rem ---
Private Function distance(p1 As Variant, p2 As Variant) As Double
    Dim a As Double
    Dim b As Double
    
    a = p2(0) - p1(0)
    b = p2(1) - p1(1)
    
    distance = Sqr((a * a) + (b * b))
    
End Function

Rem ---
Rem --- returns the max value between a and b
Rem ---
Private Function max(ByVal a As Variant, ByVal b As Variant) As Variant
    If a > b Then
        max = a
    Else
        max = b
    End If
End Function

Rem ---
Rem --- returns the min value between a and b
Rem ---
Private Function min(ByVal a As Variant, ByVal b As Variant) As Variant
    If a < b Then
        min = a
    Else
        min = b
    End If
End Function

Rem ---
Rem --- get points and break lines from selected objects
Rem ---
Public Function getObjects(ByVal handle As LongPtr) As Long
    Dim acSelSet As AcadSelectionSet
    Dim grpCode(5) As Integer
    Dim dataVal(5) As Variant
    Dim cons As Variant
    Dim acObj As AcadObject
    Dim acPoint As AcadPoint
    Dim acBlock As AcadBlockReference
    Dim ac3DPoly As Acad3DPolyline
    Dim acPoly As AcadPolyline
    Dim acLine As AcadLine
    Dim ConsList As New Collection       'constraint object list
    Dim tmpList As New Collection
    
    Dim i As Long
    Dim j As Long
    Dim k As Long
    Dim n As Long
    Dim Pt As Variant
    Dim pt1 As Variant
    
    Dim tot As Long
    
    'objects that generate points
    '"POINT"
    '"INSERT"     , check for blocks insert point
    '"LWPOLYLINE" , [Not Used] coordinates are (x,y) only, Z is elevation
    '"POLYLINE"
    '"LINE"
    
    'Valid Entities for Constraints Are:
    '"LWPOLYLINE" , [Not used] (only 2D vertices)
    '"POLYLINE"   , Open or Closed
    '"LINE"       , Make Sure you Have Z Value in Them
    
    grpCode(0) = -4
    dataVal(0) = "<OR"
    grpCode(1) = 0
    dataVal(1) = "POINT"
    grpCode(2) = 0
    dataVal(2) = "INSERT"
    'grpCode(3) = 0
    'dataVal(3) = "LWPOLYLINE"
    grpCode(3) = 0
    dataVal(3) = "POLYLINE"
    grpCode(4) = 0
    dataVal(4) = "LINE"
    grpCode(5) = -4
    dataVal(5) = "OR>"
    
    On Error GoTo ErrHandler
    
    ThisDrawing.Utility.Prompt "Select points and break lines(3D Poly) for DTM:"
    Set acSelSet = CreateSelectionSet("SS1")
    acSelSet.SelectOnScreen grpCode, dataVal
    
    If acSelSet.Count = 0 Then
        MsgBox "No objects selected for DTM"
        acSelSet.Delete
        getObjects = 0
        Exit Function
    End If
    
    For Each acObj In acSelSet
        If TypeOf acObj Is AcadPoint Then
            Set acPoint = acObj
            
            DTMLib_addPoint handle, acPoint.Coordinates(0), acPoint.Coordinates(1), acPoint.Coordinates(2)
            
        ElseIf TypeOf acObj Is AcadBlock Then
            Set acBlock = acObj
            
            DTMLib_addPoint handle, acBlock.InsertionPoint(0), acBlock.InsertionPoint(0), acBlock.InsertionPoint(0)
            
        ElseIf TypeOf acObj Is Acad3DPolyline Then
            
            Set ac3DPoly = acObj
            
            ConsList.Add ac3DPoly.Coordinates
                
            For i = LBound(ac3DPoly.Coordinates) To UBound(ac3DPoly.Coordinates) Step 3
                DTMLib_addPoint handle, ac3DPoly.Coordinates(i), ac3DPoly.Coordinates(i + 1), ac3DPoly.Coordinates(i + 2)
            Next
        ElseIf TypeOf acObj Is AcadPolyline Then
                         
            Set acPoly = acObj
            
            ConsList.Add acPoly.Coordinates
            
            For i = LBound(acPoly.Coordinates) To UBound(acPoly.Coordinates) Step 3
                DTMLib_addPoint handle, acPoly.Coordinates(i), acPoly.Coordinates(i + 1), acPoly.Coordinates(i + 2)
            Next
        ElseIf TypeOf acObj Is AcadLine Then
             
            Set acLine = acObj
                        
            ConsList.Add Array(acLine.StartPoint(0), acLine.StartPoint(1), acLine.StartPoint(2), acLine.EndPoint(0), acLine.EndPoint(1), acLine.EndPoint(2))
                        
            DTMLib_addPoint handle, acLine.StartPoint(0), acLine.StartPoint(1), acLine.StartPoint(2)
                        
            DTMLib_addPoint handle, acLine.EndPoint(0), acLine.EndPoint(1), acLine.EndPoint(2)
        End If
    Next

   
    For Each cons In ConsList
        For i = 3 To UBound(cons) Step 3
            DTMLib_addConstraint handle, cons(i - 3), cons(i - 2), cons(i), cons(i + 1)
        Next i
    Next
    
    acSelSet.Delete 'delete the selection set
    
    tot = DTMLib_pointListSize(handle)
    
    getObjects = tot
    
    Exit Function
ErrHandler:
    MsgBox Err.Description
    Stop
    Resume
End Function

Rem To find orientation of ordered triplet (p1, p2, p3).
Rem The function returns following values
Rem 0 --> p, q and r are colinear
Rem 1 --> Clockwise
Rem 2 --> Counterclockwise
Private Function orientation(ByRef p1 As Variant, ByRef p2 As Variant, ByRef p3 As Variant) As Integer
    Dim val As Double
    
    On Error GoTo ErrHandler
    
    val = (p2(1) - p1(1)) * (p3(0) - p2(0)) - (p2(0) - p1(0)) * (p3(1) - p2(1))
    
    If val < -Fuzz Then
        orientation = 2
    ElseIf val > Fuzz Then
        orientation = 1
    Else
        orientation = 0
    End If
    
    Exit Function
ErrHandler:
    Stop
    Resume
End Function

Rem ---
Rem --- check if segment a,b intersects with segment c,d (return False or True)
Rem ---
Private Function doIntersect(ByRef a As Variant, ByRef b As Variant, ByRef C As Variant, ByRef d As Variant, Optional ByVal copl As Boolean = False) As Boolean
    Dim o1 As Integer
    Dim o2 As Integer
    Dim ret As Boolean
    
    ret = True
    
    o1 = orientation(a, C, d)
    o2 = orientation(b, C, d)
    
    If o1 = o2 Or o1 = 0 Or o2 = 0 Then
        ret = False
    Else
        o1 = orientation(a, b, C)
        o2 = orientation(a, b, d)
        
        If o1 = o2 Then
            ret = False
        End If
        
        If Not copl Then
            If o1 = 0 Or o2 = 0 Then
                ret = False
            End If
        End If
    End If
    
    doIntersect = ret

End Function


Rem ---
Rem --- get intersection point between two line segments (p1,q1) - (p2,q2)
Rem --- get z from (p1,q1)
Rem ---
Private Function getIntersectPoint(ByRef p1 As Variant, ByRef q1 As Variant, ByRef p2 As Variant, ByRef q2 As Variant) As Variant
    Dim a As Double
    Dim b As Double
    Dim C As Double
    Dim d As Double
    Dim aq As Double
    Dim bq As Double
    Dim ad As Double
    Dim bd As Double
    Dim x As Double
    Dim y As Double
    Dim z As Double
    
    'l1 => y = ax + c
    'l2 => y = bx + d
    
    aq = q1(0) - p1(0)
    bq = q2(0) - p2(0)
    
    ad = q1(1) - p1(1)
    bd = q2(1) - p2(1)
    
    If aq <> 0 Then
        'y = ax + c
        a = ad / aq
        C = p1(1) - a * p1(0)
        
        If bq <> 0 Then
            'y = bx + d
            b = bd / bq
            d = p2(1) - b * p2(0)
            
            If (a = b) Then
                MsgBox "Lines are paralell"
                Stop
            Else
                x = (d - C) / (a - b)
                y = a * x + C
                
                z = (((x - p1(0)) * (q1(2) - p1(2))) / aq) + p1(2)
                
                'MsgBox "z=" & z & " x=" & x & " p1(0)=" & p1(0) & " aq=" & aq & " q1(2)=" & q1(2) & " p1(2)=" & p1(2)
            End If
        Else
            'x2 = k (vertical line)
            x = p2(0)
            y = a * x + C
            
            z = (((x - p1(0)) * (q1(2) - p1(2))) / aq) + p1(2)
        End If
    Else
        'x1 = k (vertical line)
        x = p1(0)
        
        'bq must allways be <> 0 since two vertical lines are paralell and don't cross
        b = bd / bq
        d = p2(1) - b * p2(0)
            
        y = b * x + d
            
        'for vertical lines ad is allways <> 0
        z = (((y - p1(1)) * (q1(2) - p1(2))) / ad) + p1(2)
    End If
    
    getIntersectPoint = Array(x, y, z)
End Function

Rem ---
Rem -- get index of edge in Edges List
Rem ---
Private Function getEdgePos(ByRef Edges As Variant, ByRef edge As Variant, Optional iskip As Long = -1) As Long
    Dim i As Long
    Dim medg As Variant
    Dim pos As Long
    
    pos = -1
    i = 0
    For Each medg In Edges
        i = i + 1
        If i <> iskip Then
            If (medg(0) = edge(0) And medg(1) = edge(1)) Or (medg(1) = edge(0) And medg(0) = edge(1)) Then
                pos = i
                Exit For
            End If
        End If
    Next medg
    
    getEdgePos = pos
End Function



Rem ---
Rem --- Order array with numeric data
Rem --- varData Point (x, y , z, dist)
Rem --- by dist
Rem ---
Private Sub SortByDist(ByRef varData() As Variant)
    Dim lngCounter1 As Long
    Dim lngCounter2 As Long
    Dim varTemp As Variant
    
    On Error GoTo ErrHandler

    For lngCounter1 = 2 To UBound(varData)
        varTemp = varData(lngCounter1)
        For lngCounter2 = lngCounter1 To 2 Step -1
            If varData(lngCounter2 - 1)(3) > varTemp(3) Then
                varData(lngCounter2) = varData(lngCounter2 - 1)
            Else
                Exit For
            End If
        Next lngCounter2
        varData(lngCounter2) = varTemp
    Next lngCounter1
    Exit Sub
ErrHandler:
    Stop
    Resume
End Sub

Rem ---
Rem --- check if point (p)is inside triangle (a, b, c)
Rem ---
Private Function inTriangle(ByRef p As Variant, ByRef a As Variant, ByRef b As Variant, ByRef C As Variant) As Boolean
    Dim ret As Boolean
    Dim ab As Integer
    Dim ac As Integer
    Dim bc As Integer
    Dim a_bc As Integer
    Dim b_ac As Integer
    
    ret = False
    
    ab = orientation(p, a, b)
    ac = orientation(p, a, C)
    
    If ab = 0 Or ac = 0 Then
        ret = False
    ElseIf ab <> ac Then
        bc = orientation(p, b, C)
        If bc = 0 Then
            ret = False
        Else
            a_bc = orientation(a, b, C)
            b_ac = orientation(b, a, C)
            If a_bc = bc And b_ac = ac Then
                ret = True
            End If
        End If
    End If
    inTriangle = ret
End Function

Rem ---
Rem --- check z coordinate for (x,y) in triangle (a, b, c) plane
Rem ---
Private Function getZ4Plane(ByVal x As Double, ByVal y As Double, ByRef a As Variant, ByRef b As Variant, ByRef C As Variant) As Double
    Dim z As Double
    Dim v1(2) As Double
    Dim v2(2) As Double
    Dim n(2) As Double
    Dim k As Double
    
    v1(0) = a(0) - b(0)
    v1(1) = a(1) - b(1)
    v1(2) = a(2) - b(2)
    
    v2(0) = a(0) - C(0)
    v2(1) = a(1) - C(1)
    v2(2) = a(2) - C(2)
    
    n(0) = (v1(1) * v2(2)) - (v1(2) * v2(1)) 'r
    n(1) = (v1(2) * v2(0)) - (v1(0) * v2(2)) 's
    n(2) = (v1(0) * v2(1)) - (v1(1) * v2(0)) 't
    
    If (n(2) < Fuzz And n(2) > -Fuzz) Then
        MsgBox "triangle defines a vertical plane"
        Stop
    End If
    
    k = n(0) * a(0) + n(1) * a(1) + n(2) * a(2)
    
    'plane: rx + sy + tz = k
    getZ4Plane = (k - ((n(0) * x) + (n(1) * y))) / n(2)
    
End Function

Rem ---
Rem --- Draw triangles from DLL lib to 3DFACES
Rem ---
Private Sub draw3dFaces(ByVal handle As LongPtr, ByVal tot As Long, Optional ByVal maxEdge As Double = -1)
    Dim n As Long
    Dim layerObj As AcadLayer
    Dim lcolor As New AcadAcCmColor
    Dim face As Acad3DFace
    Dim p1(3) As Double
    Dim p2(3) As Double
    Dim p3(3) As Double
    
    On Error GoTo ErrHandler
    
    lcolor.ColorIndex = myTINColor
    'create TIN Layer
    Set layerObj = ThisDrawing.Layers.Add(myTINLayer)
    
    layerObj.TrueColor = lcolor
    
    ThisDrawing.ActiveLayer = layerObj
    
    For n = 0 To tot
       DTMLib_getTriangle handle, n, p1(0), p2(0), p3(0)
        
        If maxEdge > 0 Then
            If distance(p1, p2) < maxEdge Then
                If distance(p1, p3) < maxEdge Then
                    If distance(p2, p3) < maxEdge Then
                        Set face = ThisDrawing.ModelSpace.Add3DFace(p1, p1, p2, p3)
                    End If
                End If
            End If
        Else
            Set face = ThisDrawing.ModelSpace.Add3DFace(p1, p1, p2, p3)
        End If
        
    Next n
   
    Exit Sub
ErrHandler:
    Stop
    Resume
    
End Sub

Rem ---
Rem --- get the point coordinates of a 3DPolyline at horizontal dist from first vertex
Rem ---
Private Function getPointAtDist(ByRef ac3DPoly As Acad3DPolyline, ByVal dist As Double) As Variant
    Dim totsize As Double
    Dim a As Double
    Dim b As Double
    Dim sz As Double
    Dim sdist As Double
    Dim i As Long
    Dim v1(2) As Double
    Dim v2(2) As Double
    Dim coord As Variant
    Dim x As Double
    Dim y As Double
    Dim z As Double
    Dim rf As Double
    
    coord = ac3DPoly.Coordinates
    
    v1(0) = coord(0)
    v1(1) = coord(1)
    v1(2) = coord(2)
    
    totsize = 0
    
    For i = 5 To UBound(coord) Step 3
        v2(0) = coord(i - 2)
        v2(1) = coord(i - 1)
        v2(2) = coord(i)
        
        sz = distance(v1, v2) 'horizontal distance
        
        If totsize + sz > dist Then
            'point is in this segment
            
            'distance in this segment
            sdist = dist - totsize
            
            'use triangle similarity (AA) to get coordinates
            rf = sdist / sz
            x = rf * (v2(0) - v1(0)) + v1(0)
            y = rf * (v2(1) - v1(1)) + v1(1)
            z = rf * (v2(2) - v1(2)) + v1(2)
            Exit For
        Else
            totsize = totsize + sz
        End If
        
        v1(0) = v2(0)
        v1(1) = v2(1)
        v1(2) = v2(2)
        
    Next i
    
    getPointAtDist = Array(x, y, z)
    
End Function

Rem ---
Rem --- Draw the vertical view of a 3dPolyline defined by coordinates array = coord
Rem --- with insertion point Pt and measure points with interv spacing, cot value sets the reference base line value
Rem ---
Private Sub drawVerticalView(ByRef ac3DPoly As Acad3DPolyline, ByRef Pt As Variant, ByVal interv As Double, ByVal cot As Double, Optional ByVal deform As Integer = 1)
    Dim acBaseLine As AcadPolyline
    Dim acPerfLine As AcadPolyline
    Dim acVLine As AcadLine
    Dim acCircle As AcadCircle
    Dim coord As Variant
    Dim v1(2) As Double
    Dim v2(2) As Double
    Dim x As Double
    Dim x0 As Double
    Dim SPt(2) As Double
    Dim EPt(2) As Double
    Dim IPt As Variant
    Dim perfPts() As Double
    Dim cot_form As String
    Dim text_pos(2) As Double
    Dim myTextObj As AcadText
    Dim i As Integer
    Dim dist As Double
    Dim LPt As Variant
    Dim Cp(2) As Double
        
    On Error GoTo ErrHandler
    
    coord = ac3DPoly.Coordinates
    
    cot_form = "Ref.=" & Format(cot, "#0.00")
        
    'add text for reference (base) line
    text_pos(0) = Pt(0) - myVTextHeight
    text_pos(1) = Pt(1)
    text_pos(2) = 0
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
    myTextObj.StyleName = "VTextStyle"
    myTextObj.Alignment = acAlignmentMiddleRight
    myTextObj.TextAlignmentPoint = text_pos
        
    'Vertical View
    ReDim perfPts(UBound(coord))
        
    perfPts(0) = Pt(0)
    If deform = 1 Then
        perfPts(1) = Pt(1) + coord(2) - cot
    Else
        perfPts(1) = Pt(1) + deform * (coord(2) - cot)
    End If
    perfPts(2) = 0
        
    For i = 5 To UBound(coord) Step 3
        v1(0) = coord(i - 5)
        v1(1) = coord(i - 4)
        v1(2) = coord(i - 3)
            
        v2(0) = coord(i - 2)
        v2(1) = coord(i - 1)
        v2(2) = coord(i)
            
        dist = distance(v1, v2)
        
        perfPts(i - 2) = perfPts(i - 5) + dist  ' add dist to Px
        If deform = 1 Then
            perfPts(i - 1) = Pt(1) + coord(i) - cot ' add z to Py
        Else
            perfPts(i - 1) = Pt(1) + deform * (coord(i) - cot) ' add deformed z to Py
        End If
        perfPts(i) = 0
    Next i
        
    Set acPerfLine = ThisDrawing.ModelSpace.AddPolyline(perfPts)
            
    'Base Line
    ReDim perfPts(UBound(coord))
        
    perfPts(0) = Pt(0)
    perfPts(1) = Pt(1)
    perfPts(2) = 0
        
    For i = 5 To UBound(coord) Step 3
        v1(0) = coord(i - 5)
        v1(1) = coord(i - 4)
        v1(2) = coord(i - 3)
            
        v2(0) = coord(i - 2)
        v2(1) = coord(i - 1)
        v2(2) = coord(i)
            
        dist = distance(v1, v2)
            
        perfPts(i - 2) = perfPts(i - 5) + dist ' add dist to Px
        perfPts(i - 1) = Pt(1)
        perfPts(i) = 0
    Next i
        
    Set acBaseLine = ThisDrawing.ModelSpace.AddPolyline(perfPts)
        
    'measure at interv
    i = 0
    x0 = 0
    For x = Pt(0) To perfPts(UBound(perfPts) - 2) Step interv
        'make sure text for last point doesn't get on top of previous text
        If x + myVTextHeight < perfPts(UBound(perfPts) - 2) Then
            
            i = i + 1
            
            SPt(0) = x
            SPt(1) = Pt(1)
            SPt(2) = 0
            EPt(0) = x
            EPt(1) = Pt(1) + 5
            EPt(2) = 0
            Set acVLine = ThisDrawing.ModelSpace.AddLine(SPt, EPt)
            IPt = acVLine.IntersectWith(acPerfLine, acExtendThisEntity)
            acVLine.Delete
            EPt(0) = IPt(0)
            EPt(1) = IPt(1)
            ThisDrawing.ModelSpace.AddLine SPt, EPt
                
            'height
            text_pos(0) = x
            text_pos(1) = Pt(1) - (1 + myTextHeight)
                
            If deform = 1 Then
                cot_form = Format((EPt(1) - SPt(1)) + cot, "#0.00")
            Else
                cot_form = Format(((EPt(1) - SPt(1)) / deform) + cot, "#0.00")
            End If
                
            Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
            myTextObj.StyleName = "VTextStyle"
            myTextObj.Rotation = PI2  '90 deg = pi/2
            myTextObj.Alignment = acAlignmentMiddleCenter
            myTextObj.TextAlignmentPoint = text_pos
                
            'Parcial x
            text_pos(1) = text_pos(1) - (myTextHeight * 2)
                
            If x0 = 0 Then
                cot_form = Format(0, "#0.00")
            Else
                cot_form = Format(x - x0, "#0.00")
            End If
                
            x0 = x
                
            Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
            myTextObj.StyleName = "VTextStyle"
            myTextObj.Rotation = PI2  '90 deg = pi/2
            myTextObj.Alignment = acAlignmentMiddleCenter
            myTextObj.TextAlignmentPoint = text_pos
            
            'dist to orig
            text_pos(1) = text_pos(1) - (myTextHeight * 2)
                
            cot_form = Format(x - Pt(0), "#0.00")
            Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
            myTextObj.StyleName = "VTextStyle"
            myTextObj.Rotation = PI2  '90 deg = pi/2
            myTextObj.Alignment = acAlignmentMiddleCenter
            myTextObj.TextAlignmentPoint = text_pos
            
            'label
            text_pos(1) = text_pos(1) - (myTextHeight * 2)
            cot_form = "P" & i
            Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
            myTextObj.StyleName = "VTextStyle"
            myTextObj.Rotation = PI2  '90 deg = pi/2
            myTextObj.Alignment = acAlignmentMiddleCenter
            myTextObj.TextAlignmentPoint = text_pos
            
            If deform = 1 Then
                'draw label on ac3DPoly
                LPt = getPointAtDist(ac3DPoly, x - Pt(0))
                Cp(0) = LPt(0)
                Cp(1) = LPt(1)
                Cp(2) = LPt(2)
                Set acCircle = ThisDrawing.ModelSpace.AddCircle(Cp, myVTextHeight * 0.3)
                
                Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, Cp, myVTextHeight)
                myTextObj.StyleName = "VTextStyle"
                myTextObj.Rotation = PI2  '90 deg = pi/2
                myTextObj.Alignment = acAlignmentMiddleLeft
                myTextObj.TextAlignmentPoint = Cp
            End If
            
        End If
    Next x
    
    i = i + 1
        
    'draw last point
    SPt(0) = perfPts(UBound(perfPts) - 2)
    SPt(1) = Pt(1)
    SPt(2) = 0
    EPt(0) = perfPts(UBound(perfPts) - 2)
    EPt(1) = Pt(1) + 5
    EPt(2) = 0
    Set acVLine = ThisDrawing.ModelSpace.AddLine(SPt, EPt)
    IPt = acVLine.IntersectWith(acPerfLine, acExtendThisEntity)
    acVLine.Delete
    EPt(0) = IPt(0)
    EPt(1) = IPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
            
    'height
    text_pos(0) = SPt(0)
    text_pos(1) = Pt(1) - (1 + myTextHeight)
            
    If deform = 1 Then
        cot_form = Format((EPt(1) - SPt(1)) + cot, "#0.00")
    Else
        cot_form = Format(((EPt(1) - SPt(1)) / deform) + cot, "#0.00")
    End If
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
    myTextObj.StyleName = "VTextStyle"
    myTextObj.Rotation = PI2 '90 deg = pi/2
    myTextObj.Alignment = acAlignmentMiddleCenter
    myTextObj.TextAlignmentPoint = text_pos
            
    'Parcial x
    text_pos(1) = text_pos(1) - (myTextHeight * 2)
            
    If x0 = 0 Then
        cot_form = Format(0, "#0.00")
    Else
        cot_form = Format(SPt(0) - x0, "#0.00")
    End If

    Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
    myTextObj.StyleName = "VTextStyle"
    myTextObj.Rotation = PI2  '90 deg = pi/2
    myTextObj.Alignment = acAlignmentMiddleCenter
    myTextObj.TextAlignmentPoint = text_pos
            
    'dist to orig
    text_pos(1) = text_pos(1) - (myTextHeight * 2)
            
    cot_form = Format(SPt(0) - Pt(0), "#0.00")
    Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
    myTextObj.StyleName = "VTextStyle"
    myTextObj.Rotation = PI2  '90 deg = pi/2
    myTextObj.Alignment = acAlignmentMiddleCenter
    myTextObj.TextAlignmentPoint = text_pos
    
    'label
    text_pos(1) = text_pos(1) - (myTextHeight * 2)
    cot_form = "P" & i
    Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, text_pos, myVTextHeight)
    myTextObj.StyleName = "VTextStyle"
    myTextObj.Rotation = PI2  '90 deg = pi/2
    myTextObj.Alignment = acAlignmentMiddleCenter
    myTextObj.TextAlignmentPoint = text_pos
            
    If deform = 1 Then
        'draw label on ac3DPoly
        Cp(0) = coord(UBound(coord) - 2)
        Cp(1) = coord(UBound(coord) - 1)
        Cp(2) = coord(UBound(coord))
        Set acCircle = ThisDrawing.ModelSpace.AddCircle(Cp, myVTextHeight * 0.3)
                
        Set myTextObj = ThisDrawing.ModelSpace.AddText(cot_form, Cp, myVTextHeight)
        myTextObj.StyleName = "VTextStyle"
        myTextObj.Rotation = PI2  '90 deg = pi/2
        myTextObj.Alignment = acAlignmentMiddleLeft
        myTextObj.TextAlignmentPoint = Cp
    End If
            
    'draw table
    SPt(0) = Pt(0) - 14
    SPt(1) = Pt(1) - 1
    EPt(0) = perfPts(UBound(perfPts) - 2) + 1
    EPt(1) = SPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
        
    text_pos(0) = SPt(0) + myTextHeight
    text_pos(1) = SPt(1) - (myTextHeight * 1.5)
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText("Cota Terreno", text_pos, myTextHeight)
    myTextObj.StyleName = "HTextStyle"
        
    SPt(1) = SPt(1) - (myTextHeight * 2)
    EPt(1) = SPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
        
    text_pos(1) = SPt(1) - (myTextHeight * 1.5)
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText("Distancia Parcial", text_pos, myTextHeight)
    myTextObj.StyleName = "HTextStyle"
        
    SPt(1) = SPt(1) - (myTextHeight * 2)
    EPt(1) = SPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
        
    text_pos(1) = SPt(1) - (myTextHeight * 1.5)
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText("Distancia Origem", text_pos, myTextHeight)
    myTextObj.StyleName = "HTextStyle"
        
    SPt(1) = SPt(1) - (myTextHeight * 2)
    EPt(1) = SPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
    
    text_pos(1) = SPt(1) - (myTextHeight * 1.5)
            
    Set myTextObj = ThisDrawing.ModelSpace.AddText("Perfil", text_pos, myTextHeight)
    myTextObj.StyleName = "HTextStyle"
        
    SPt(1) = SPt(1) - (myTextHeight * 2)
    EPt(1) = SPt(1)
    ThisDrawing.ModelSpace.AddLine SPt, EPt
    
    Exit Sub
ErrHandler:
    MsgBox Err.Description
    Stop
    Resume
End Sub

Rem ---
Rem --- this function returns a selection set with the given name
Rem --- if a selectionset with the given name already exists, it returns that selectionset after clearing it
Rem --- if a selectionset with the given name doesn't exist, it creates a new selectionset and returns it
Rem ---
Private Function CreateSelectionSet(selsetName As String, Optional acDoc As Variant) As AcadSelectionSet

    Dim acSelSet As AcadSelectionSet
    
    If IsMissing(acDoc) Then Set acDoc = ThisDrawing
    
    On Error Resume Next
    Set acSelSet = acDoc.SelectionSets.Item(selsetName) 'try to get an exisisting selection set
    On Error GoTo 0
    If acSelSet Is Nothing Then Set acSelSet = acDoc.SelectionSets.Add(selsetName) 'if unsuccsessful, then create it
    
    acSelSet.Clear 'cleare the selection set
    
    Set CreateSelectionSet = acSelSet
End Function

Rem ---
Rem --- Returns a SelectionSet of entities of type EntityType in layer Layername
Rem ---
Private Function GetEntityTypeInLayer(entityType As String, LayerName As String) As AcadSelectionSet
    Dim acSelSet As AcadSelectionSet
    Dim grpCode(1) As Integer
    Dim dataVal(1) As Variant
    
    grpCode(0) = 0: dataVal(0) = entityType 'this will filter for the entity type passed with "entityType"
    grpCode(1) = 8: dataVal(1) = LayerName 'this will filter for layer with name as the one passed with "layerName" argument
    
    Set acSelSet = CreateSelectionSet("sset", ThisDrawing) 'create a selection set via a proper function
    acSelSet.Select acSelectionSetAll, , , grpCode, dataVal ' fill it with all elements filtered as above: LWPolylines in layer with name passed via "layername" argument
    Set GetEntityTypeInLayer = acSelSet 'acSelSet.Count 'count the numbers of element in the selectionset
End Function

Rem ---
Rem --- create a text style
Rem ---
Private Function createTextStyle(ByVal name As String, ByVal font As String, ByVal height As Double) As AcadTextStyle
    Dim Textstyleslist As String
    Dim styleExists As Boolean
    Dim TStyle As AcadTextStyle
    Dim n As Integer
    
    styleExists = False
    
    For n = 0 To ThisDrawing.TextStyles.Count - 1
        If StrComp(name, ThisDrawing.TextStyles.Item(n).name, vbTextCompare) = 0 Then
            styleExists = True
            Exit For
        End If
    Next n
    
    If Not styleExists Then
        Set TStyle = ThisDrawing.TextStyles.Add(name)
    Else
        Set TStyle = ThisDrawing.TextStyles.Item(n)
    End If
    
    TStyle.SetFont font, False, False, DEFAULT_CHARSET, DEFAULT_PITCH
    TStyle.height = height
    
    Set createTextStyle = TStyle
End Function

Rem ---
Rem --- generates 3dface triangles surfaces from Delauney constrained triangulation of selected points and 3dPolylines
Rem ---
Public Function createTIN(ByVal maxEdge As Double) As Long
    
    Dim sPath As String
    Dim mPath As String
    
    sPath = ThisDrawing.Application.VBE.ActiveVBProject.filename
    
    mPath = getPath(sPath)
    
    ChDir mPath
    
    Dim tot As Long
    Dim nPoints As Long
    
    Dim handle As LongPtr
    handle = DTMLib_init
    
    'get points and constraints
    nPoints = getObjects(handle)
    
    If nPoints = 0 Then
        createTIN = 0
        Exit Function
    End If
    
    ' get delauney triangulation
    tot = DTMLib_triangulate(handle)
    
    'draw triangles
    draw3dFaces handle, tot, maxEdge
    
    MsgBox "generated " & tot & " triangles from " & nPoints & " Points"
    
    DTMLib_close handle
    
    createTIN = tot

End Function

Rem ---
Rem --- generates level lines from selected 3DFaces
Rem ---
Public Sub createCN(ByVal CNPStep As Double, ByVal CNSStep As Double, Optional ByVal useTINLayer As Boolean = True)
     Dim acSelSet As AcadSelectionSet
    Dim oGr As AcadGroup
    Dim oGrName As String
    Dim ssobjs() As AcadEntity
    Dim acObj As AcadEntity
    Dim grpCode(0) As Integer
    Dim dataVal(0) As Variant
    Dim nface As Integer
    Dim acFace As Acad3DFace
    Dim CNPLayer As AcadLayer
    Dim CNSLayer As AcadLayer
    Dim acPoly As AcadPolyline
    Dim lcolor As New AcadAcCmColor
    Dim Elevations(2) As Double
    Dim CNsize As Integer
    Dim Zstart As Double
    Dim Zend As Double
    Dim Zi As Double
    Dim v1(0 To 2) As Double
    Dim v2(0 To 2) As Double
    Dim v3(0 To 2) As Double
    Dim p1(0 To 1) As Double
    Dim p2(0 To 1) As Double
    Dim points() As Double
    Dim hasP1 As Boolean
    Dim hasP2 As Boolean
    Dim l As Double
    Dim m As Double
    Dim n As Double
    Dim ZN As Double
    Dim md As Double
    Dim oi As Long
    
    On Error GoTo ErrHandler
    
    If useTINLayer Then
        Set acSelSet = GetEntityTypeInLayer("3DFACE", myTINLayer)
        If acSelSet.Count = 0 Then
            MsgBox "No 3DFACE objects selected"
            acSelSet.Delete
            Exit Sub
        End If
    Else
        grpCode(0) = 0
        dataVal(0) = "3DFACE"
        
        Set acSelSet = CreateSelectionSet("SS1")

        acSelSet.SelectOnScreen grpCode, dataVal
        
        If acSelSet.Count = 0 Then
            MsgBox "No 3DFACE objects selected"
            acSelSet.Delete
            Exit Sub
        End If
    End If
    
    For Each acFace In acSelSet
        If Elevations(0) = 0 Then
            Elevations(0) = acFace.Coordinates(5)
        Else
            Elevations(0) = min(Elevations(0), acFace.Coordinates(5))
            Elevations(0) = min(Elevations(0), acFace.Coordinates(8))
            Elevations(0) = min(Elevations(0), acFace.Coordinates(11))
        End If
            
        If Elevations(1) = 0 Then
            Elevations(1) = acFace.Coordinates(5)
        Else
            Elevations(1) = max(Elevations(1), acFace.Coordinates(5))
            Elevations(1) = max(Elevations(1), acFace.Coordinates(8))
            Elevations(1) = max(Elevations(1), acFace.Coordinates(11))
        End If
    Next acFace
    
    Zstart = Int(Elevations(0))
    Zend = Int(Elevations(1) + 0.99999999999)
    
    While Zstart < Elevations(0)
        Zstart = Zstart + CNSStep
    Wend
    
    While Zend > Elevations(1)
        Zend = Zend - CNSStep
    Wend
    
    lcolor.ColorIndex = myCNPColor
    Set CNPLayer = ThisDrawing.Layers.Add(myCNPLayer)
    CNPLayer.TrueColor = lcolor
    
    lcolor.ColorIndex = myCNSColor
    Set CNSLayer = ThisDrawing.Layers.Add(myCNSLayer)
    CNSLayer.TrueColor = lcolor
    
    CNsize = 0
    
    oGrName = "POLGRP"

    For Zi = Zstart To Zend Step CNSStep
        
        oi = 0
        Set oGr = ThisDrawing.Groups.Add(oGrName)
        
        For Each acFace In acSelSet
            'check vertex
            
            v1(0) = acFace.Coordinates(3)
            v1(1) = acFace.Coordinates(4)
            v1(2) = acFace.Coordinates(5)
            v2(0) = acFace.Coordinates(6)
            v2(1) = acFace.Coordinates(7)
            v2(2) = acFace.Coordinates(8)
            v3(0) = acFace.Coordinates(9)
            v3(1) = acFace.Coordinates(10)
            v3(2) = acFace.Coordinates(11)
            hasP1 = False
            hasP2 = False
            
            If (v1(2) >= Zi Or v2(2) >= Zi Or v3(2) >= Zi) And (v1(2) < Zi Or v2(2) < Zi Or v3(2) < Zi) Then
                'check V12 interstion on Zi Plane
                If (v1(2) >= Zi Or v2(2) >= Zi) And (v1(2) < Zi Or v2(2) < Zi) Then
                   l = v2(0) - v1(0)
                   m = v2(1) - v1(1)
                   n = v2(2) - v1(2)
                   ZN = (Zi - v1(2)) / n
                   p1(0) = l * ZN + v1(0)
                   p1(1) = m * ZN + v1(1)
                   'P1(2) = Zi
                   hasP1 = True
                End If
                'check V23 interstion on Zi Plane
                If (v2(2) >= Zi Or v3(2) >= Zi) And (v2(2) < Zi Or v3(2) < Zi) Then
                    l = v3(0) - v2(0)
                    m = v3(1) - v2(1)
                    n = v3(2) - v2(2)
                    ZN = (Zi - v2(2)) / n
                    If hasP1 Then
                        p2(0) = l * ZN + v2(0)
                        p2(1) = m * ZN + v2(1)
                        'P2(2) = Zi
                        hasP2 = True
                    Else
                        p1(0) = l * ZN + v2(0)
                        p1(1) = m * ZN + v2(1)
                        'P1(2) = Zi
                        hasP1 = True
                    End If
                End If
                'check V13 interstion on Zi Plane
                If Not hasP2 And (v3(2) >= Zi Or v1(2) >= Zi) And (v3(2) < Zi Or v1(2) < Zi) Then
                    l = v3(0) - v1(0)
                    m = v3(1) - v1(1)
                    n = v3(2) - v1(2)
                    ZN = (Zi - v1(2)) / n
                    If hasP1 Then
                        p2(0) = l * ZN + v1(0)
                        p2(1) = m * ZN + v1(1)
                       'P2(2) = Zi
                        hasP2 = True
                    Else
                        p1(0) = l * ZN + v1(0)
                        p1(1) = m * ZN + v1(1)
                        'P1(2) = Zi
                        hasP1 = True
                    End If
                End If
                
                If hasP2 Then
                    CNsize = CNsize + 9
                    ReDim Preserve points(0 To CNsize - 1)
                    
                    points(CNsize - 9) = p1(0)
                    points(CNsize - 8) = p1(1)
                    points(CNsize - 7) = Zi
                    
                    'add a middle point fo P12
                    points(CNsize - 6) = ((p2(0) - p1(0)) / 2) + p1(0)
                    points(CNsize - 5) = ((p2(1) - p1(1)) / 2) + p1(1)
                    points(CNsize - 4) = Zi
                    
                    points(CNsize - 3) = p2(0)
                    points(CNsize - 2) = p2(1)
                    points(CNsize - 1) = Zi
                    
                    Set acPoly = ThisDrawing.ModelSpace.AddPolyline(points)
                    acPoly.Elevation = Zi
                    
                    md = Int((Zi / CNPStep) + Fuzz)
                    If (Zi / CNPStep) > md + Fuzz Then
                        acPoly.Layer = myCNSLayer
                    Else
                        acPoly.Layer = myCNPLayer
                    End If
                    
                    ReDim Preserve ssobjs(oi)
                    Set ssobjs(oi) = acPoly
                    oi = oi + 1
                    
                    'acPoly.Highlight True
                    CNsize = 0
                    Erase points
                    
                End If
            End If
        Next
        
        oGr.AppendItems ssobjs
        
        'Join
        ThisDrawing.SendCommand "_JOIN" & vbCr & "G" & vbCr & oGrName & vbCr & vbCr
        'ThisDrawing.SendCommand "_PEDIT" & vbCr & "M" & vbCr & "G" & vbCr & oGrName & vbCr & vbCr & "J" & vbCr & "0.01" & vbCr & vbCr
        
        oGr.Delete
    Next Zi
    
    acSelSet.Delete
    
    'SPline for closed Polylines or Fit for open Polilines
    'ThisDrawing.SendCommand "_PEDIT" & vbCr & "M" & vbCr & "PRO" & vbCr & "LA" & vbCr & myCNPLayer & vbCr & vbCr & vbCr & "S" & vbCr & vbCr
    'ThisDrawing.SendCommand "_PEDIT" & vbCr & "M" & vbCr & "PRO" & vbCr & "LA" & vbCr & myCNSLayer & vbCr & vbCr & vbCr & "S" & vbCr & vbCr
    
    'For ZWCad Pedit doesn't filter so use selection sets
    Set acSelSet = GetEntityTypeInLayer("LWPOLYLINE", myCNPLayer)
    If acSelSet.Count > 0 Then
        ReDim ssobjs(acSelSet.Count - 1)
        oi = 0
        For Each acObj In acSelSet
            Set ssobjs(oi) = acObj
            oi = oi + 1
        Next acObj
        oGrName = "CNGRP"
        Set oGr = ThisDrawing.Groups.Add(oGrName)
        oGr.AppendItems ssobjs
        ThisDrawing.SendCommand "_PEDIT" & vbCr & "M" & vbCr & "G" & vbCr & oGrName & vbCr & vbCr & "S" & vbCr & vbCr
        oGr.Delete
    End If
    acSelSet.Delete
    Set acSelSet = GetEntityTypeInLayer("LWPOLYLINE", myCNSLayer)
    If acSelSet.Count > 0 Then
        ReDim ssobjs(acSelSet.Count - 1)
        oi = 0
        For Each acObj In acSelSet
            Set ssobjs(oi) = acObj
            oi = oi + 1
        Next acObj
        oGrName = "CNGRP"
        Set oGr = ThisDrawing.Groups.Add(oGrName)
        oGr.AppendItems ssobjs
        ThisDrawing.SendCommand "_PEDIT" & vbCr & "M" & vbCr & "G" & vbCr & oGrName & vbCr & vbCr & "S" & vbCr & vbCr
        oGr.Delete
    End If
    acSelSet.Delete
    
    Exit Sub
ErrHandler:
    MsgBox Err.Description
    Stop
    Resume
End Sub

Rem ---
Rem --- create aligment with selected 3dfaces from a 2d Polyline
Rem ---
Public Sub createALIG()
    Dim acSelSetA As AcadSelectionSet
    Dim acSelSetB As AcadSelectionSet
    Dim grpCode() As Integer
    Dim dataVal() As Variant
    Dim oGr As AcadGroup
    Dim oGrName As String
    Dim ssobjs() As AcadEntity
    Dim nObj As Integer
    Dim acLayer As AcadLayer
    Dim acObj As AcadObject
    Dim acPoly As AcadPolyline
    Dim acLWPoly As AcadLWPolyline
    Dim acFace As Acad3DFace
    Dim v1 As Variant
    Dim v2 As Variant
    Dim v3 As Variant
    Dim vertNum As Integer
    Dim VERT() As Variant
    Dim PtLst() As Variant
    Dim PtNum As Integer
    Dim PCount As Integer
    Dim alPt() As Double
    Dim Pt As Variant
    Dim i As Integer
    Dim j As Integer
    Dim x As Double
    Dim y As Double
    Dim z As Double
    Dim dist As Double
    
    On Error GoTo ErrHandler
    
    ReDim grpCode(3)
    ReDim dataVal(3)
    
    grpCode(0) = -4
    dataVal(0) = "<OR"
    grpCode(1) = 0
    dataVal(1) = "POLYLINE"
    grpCode(2) = 0
    dataVal(2) = "LWPOLYLINE"
    grpCode(3) = -4
    dataVal(3) = "OR>"
        
    ThisDrawing.Utility.Prompt "Select Polylines to align:"
    Set acSelSetA = CreateSelectionSet("PolyALIG")
    acSelSetA.SelectOnScreen grpCode, dataVal
    
    If acSelSetA.Count = 0 Then
        MsgBox "No Polyline objects selected"
        acSelSetA.Delete
        Exit Sub
    End If
    
    ReDim grpCode(0)
    ReDim dataVal(0)
    
    grpCode(0) = 0
    dataVal(0) = "3DFACE"
    
    ThisDrawing.Utility.Prompt "Select 3DFaces for alignment:"
    Set acSelSetB = CreateSelectionSet("FaceALIG")
    acSelSetB.SelectOnScreen grpCode, dataVal
    
    If acSelSetB.Count = 0 Then
        MsgBox "No 3DFace objects selected"
        acSelSetB.Delete
        acSelSetA.Delete
        Exit Sub
    End If
    
    If acSelSetA.Count > 0 Then
        For Each acObj In acSelSetA
            nObj = -1
            If TypeOf acObj Is AcadPolyline Then
                Set acPoly = acObj
                
                ThisDrawing.ActiveLayer = ThisDrawing.Layers(acPoly.Layer)
            
                vertNum = 0
                For i = LBound(acPoly.Coordinates) + 2 To UBound(acPoly.Coordinates) Step 3
                    vertNum = vertNum + 1
                    x = acPoly.Coordinates(i - 2)
                    y = acPoly.Coordinates(i - 1)
                    
                    ReDim Preserve VERT(1 To vertNum)
                    
                    VERT(vertNum) = Array(x, y, 0)
                Next i
            ElseIf TypeOf acObj Is AcadLWPolyline Then
                Set acLWPoly = acObj
                
                ThisDrawing.ActiveLayer = ThisDrawing.Layers(acLWPoly.Layer)
                
                vertNum = 0
                For i = LBound(acLWPoly.Coordinates) + 1 To UBound(acLWPoly.Coordinates) Step 2
                    vertNum = vertNum + 1
                    x = acLWPoly.Coordinates(i - 1)
                    y = acLWPoly.Coordinates(i)
                    
                    ReDim Preserve VERT(1 To vertNum)
                    
                    VERT(vertNum) = Array(x, y, 0)
                Next i
            Else
                MsgBox "Object is not a Polyline or LWPolyline"
            End If
                
            PCount = -1
            For i = 2 To vertNum
                PtNum = 0
                For Each acFace In acSelSetB
                    v1 = Array(acFace.Coordinates(3), acFace.Coordinates(4), acFace.Coordinates(5))
                    v2 = Array(acFace.Coordinates(6), acFace.Coordinates(7), acFace.Coordinates(8))
                    v3 = Array(acFace.Coordinates(9), acFace.Coordinates(10), acFace.Coordinates(11))
                    
                    If inTriangle(VERT(i - 1), v1, v2, v3) Then
                        x = VERT(i - 1)(0)
                        y = VERT(i - 1)(1)
                        z = getZ4Plane(x, y, v1, v2, v3)
                            
                        dist = distance(VERT(i - 1), Array(x, y))
                        
                        PtNum = PtNum + 1
                        ReDim Preserve PtLst(1 To PtNum)
                        If (PtNum > 1) Then
                            If PtLst(PtNum - 1)(3) < dist Then
                                PtLst(PtNum) = Array(x, y, z, dist)
                            Else
                                PtLst(PtNum) = PtLst(PtNum - 1)
                                PtLst(PtNum - 1) = Array(x, y, z, dist)
                            End If
                        Else
                            PtLst(PtNum) = Array(x, y, z, dist)
                        End If
                    End If
                    
                    If doIntersect(v1, v2, VERT(i - 1), VERT(i), True) Then
                        Pt = getIntersectPoint(v1, v2, VERT(i - 1), VERT(i))
                        x = Pt(0)
                        y = Pt(1)
                        z = Pt(2)
                        
                        dist = distance(VERT(i - 1), Array(x, y))
                        
                        PtNum = PtNum + 1
                        ReDim Preserve PtLst(1 To PtNum)
                        If (PtNum > 1) Then
                            If PtLst(PtNum - 1)(3) < dist Then
                                PtLst(PtNum) = Array(x, y, z, dist)
                            Else
                                PtLst(PtNum) = PtLst(PtNum - 1)
                                PtLst(PtNum - 1) = Array(x, y, z, dist)
                            End If
                        Else
                            PtLst(PtNum) = Array(x, y, z, dist)
                        End If
                    End If
                    If doIntersect(v1, v3, VERT(i - 1), VERT(i), True) Then
                        Pt = getIntersectPoint(v1, v3, VERT(i - 1), VERT(i))
                        x = Pt(0)
                        y = Pt(1)
                        z = Pt(2)
                        
                        dist = distance(VERT(i - 1), Array(x, y))
                        
                        PtNum = PtNum + 1
                        ReDim Preserve PtLst(1 To PtNum)
                        If (PtNum > 1) Then
                            If PtLst(PtNum - 1)(3) < dist Then
                                PtLst(PtNum) = Array(x, y, z, dist)
                            Else
                                PtLst(PtNum) = PtLst(PtNum - 1)
                                PtLst(PtNum - 1) = Array(x, y, z, dist)
                            End If
                        Else
                            PtLst(PtNum) = Array(x, y, z, dist)
                        End If
                    End If
                    If doIntersect(v2, v3, VERT(i - 1), VERT(i), True) Then
                        Pt = getIntersectPoint(v2, v3, VERT(i - 1), VERT(i))
                        x = Pt(0)
                        y = Pt(1)
                        z = Pt(2)
                        
                        dist = distance(VERT(i - 1), Array(x, y))
                        
                        PtNum = PtNum + 1
                        ReDim Preserve PtLst(1 To PtNum)
                        If (PtNum > 1) Then
                            If PtLst(PtNum - 1)(3) < dist Then
                                PtLst(PtNum) = Array(x, y, z, dist)
                            Else
                                PtLst(PtNum) = PtLst(PtNum - 1)
                                PtLst(PtNum - 1) = Array(x, y, z, dist)
                            End If
                        Else
                            PtLst(PtNum) = Array(x, y, z, dist)
                        End If
                    End If
                        
                    If i = vertNum And inTriangle(VERT(i), v1, v2, v3) Then
                        x = VERT(i)(0)
                        y = VERT(i)(1)
                        z = getZ4Plane(x, y, v1, v2, v3)
                            
                        dist = distance(VERT(i - 1), Array(x, y))
                        
                        PtNum = PtNum + 1
                        ReDim Preserve PtLst(1 To PtNum)
                        If (PtNum > 1) Then
                            If PtLst(PtNum - 1)(3) < dist Then
                                PtLst(PtNum) = Array(x, y, z, dist)
                            Else
                                PtLst(PtNum) = PtLst(PtNum - 1)
                                PtLst(PtNum - 1) = Array(x, y, z, dist)
                            End If
                        Else
                            PtLst(PtNum) = Array(x, y, z, dist)
                        End If
                    End If
                Next acFace
                
                SortByDist PtLst
                
                j = 0
                For Each Pt In PtLst
                    j = j + 1
                    If PCount < 0 Then
                        PCount = PCount + 3
                        ReDim Preserve alPt(PCount)
                        alPt(0) = Pt(0)
                        alPt(1) = Pt(1)
                        alPt(2) = Pt(2)
                    ElseIf Pt(0) < alPt(PCount - 2) - Fuzz Or Pt(0) > alPt(PCount - 2) + Fuzz Or Pt(1) < alPt(PCount - 1) - Fuzz Or Pt(1) > alPt(PCount - 1) + Fuzz Then
                        PCount = PCount + 3
                        ReDim Preserve alPt(PCount)
                        alPt(PCount - 2) = Pt(0)
                        alPt(PCount - 1) = Pt(1)
                        alPt(PCount) = Pt(2)
                    End If
                Next Pt
            Next i
                
                
            If PCount > 4 Then
                ThisDrawing.ModelSpace.Add3DPoly (alPt)
            End If
            
            'delete original line
            acObj.Delete
            
        Next acObj
    End If
    
    acSelSetA.Delete
    acSelSetB.Delete
    
    Exit Sub
ErrHandler:
    MsgBox Err.Description
    Stop
    Resume
End Sub

Rem ---
Rem --- create Vertical views for selected 3DPolylines
Rem ---
Public Sub createVERT()
    Dim acSelSet As AcadSelectionSet
    Dim acSelSetB As AcadSelectionSet
    Dim grpCode() As Integer
    Dim dataVal() As Variant
    Dim ac3DPoly As Acad3DPolyline
    Dim myHTStyle As AcadTextStyle
    Dim myVTStyle As AcadTextStyle
    Dim Pt As Variant
    Dim i As Integer
    Dim interv As Double
    Dim Zmin As Double
    Dim Zmax As Double
    Dim cot As Double
    Dim kwordList As String
    Dim rStr As String
    
    On Error GoTo ErrHandler
    
    ' Create a new dimension style
    Set myHTStyle = createTextStyle("HTextStyle", "Tahoma", myTextHeight)
    
    Set myVTStyle = createTextStyle("VTextStyle", "Tahoma", myVTextHeight)
    
    ReDim grpCode(0)
    ReDim dataVal(0)
    
    grpCode(0) = 0
    dataVal(0) = "POLYLINE"
    
    ThisDrawing.Utility.Prompt "Select 3D Polylines for vertical view:"
    Set acSelSet = CreateSelectionSet("3DPVERT")
    acSelSet.SelectOnScreen grpCode, dataVal
    
    If acSelSet.Count = 0 Then
        MsgBox "No 3D Polyline objects selected"
        acSelSet.Delete
        Exit Sub
    End If
    
    interv = 2
    interv = ThisDrawing.Utility.GetReal("Select the distance between measure points (" & interv & "):")
            
    If interv <= Fuzz Then
        MsgBox "Distance must be bigger than " & Fuzz
        Exit Sub
    End If
    
    For Each ac3DPoly In acSelSet
    
        Zmin = ac3DPoly.Coordinates(2)
        Zmax = ac3DPoly.Coordinates(2)
        For i = 5 To UBound(ac3DPoly.Coordinates) Step 3
           Zmin = min(Zmin, ac3DPoly.Coordinates(i))
           Zmax = max(Zmin, ac3DPoly.Coordinates(i))
        Next i
        
        cot = Int(Zmin)
        cot = cot - 5
        If cot < 0 Then
            cot = 0
        End If
            
        ThisDrawing.ActiveLayer = ThisDrawing.Layers(ac3DPoly.Layer)
        
        Pt = ThisDrawing.Utility.getPoint(, "Select the insertion point:")
        
        drawVerticalView ac3DPoly, Pt, interv, cot
        
        kwordList = "Yes No"
        ThisDrawing.Utility.InitializeUserInput 1, kwordList
        
        rStr = ThisDrawing.Utility.GetKeyword(vbLf & "Create deformed view (x10) [Yes/No]: ")
        rStr = Mid(rStr, 1, 1) 'Y or N
        
        If StrComp(rStr, "Y", vbTextCompare) = 0 Then
            cot = Int(Zmin)
            cot = cot - 0.5
            
            If cot < 0 Then
                cot = 0
            End If
            
            Pt = ThisDrawing.Utility.getPoint(, "Select the insertion point:")
            
            drawVerticalView ac3DPoly, Pt, interv, cot, 10
        End If
          
    Next ac3DPoly
    
    acSelSet.Delete
    
    Exit Sub
ErrHandler:
    Select Case Err.Number
        Case ERR_COMMAND_CANCELED
            acSelSet.Delete
            Exit Sub
        Case ERR_GETVALUE_CANCELED
            acSelSet.Delete
            Exit Sub
        Case ERR_EMPTY_POINT
            acSelSet.Delete
            Exit Sub
        Case ERR_EMPTY_VALUE
            Resume Next
        Case ERR_EMPTY_VALUE_ZCAD
            Resume Next
    End Select

    MsgBox Err.Description & " (" & Err.Number & ")"
    Stop
    Resume
End Sub

