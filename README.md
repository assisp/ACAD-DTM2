# ACAD-DTM2
Acad VBA with the use of a cpp DLL based on artem-ogre/CDT (https://github.com/artem-ogre/CDT)

This version although not fully VBA like https://github.com/assisp/VBA-DTM is much faster generating 
the Triangulated irregular network (TIN) since it's based on the incredible CDT code from artem-ogre

Generate TIN with Delauney constraint triangulation of points in Autocad

Generate Contour Lines from TIN

Align 2d Polylines to TIN surface (generate 3D Polyline)

Create Vertical Views of 3D Polylines

Installation:

Build DLL:
  with msys2 (you can replace g++ with clang++):
    (make sure to have libboost installed: pacman -S mingw-w64-x86_64-boost)
    g++ -c -o DTM2.o DTM2.cpp
    g++ -shared -v -o DTM2.dll DTM2.o

Add files to Acad or Bricscad VBA project: (DTM.bas, clsDTM.cls, UserForm1.frm and UserForm2.frm)
Add DTM2.dll and build dependencies (libgcc_s_seh-1.dll, libstdc++-6.dll and libwinpthread-1.dll 
to the same dir of the VBA project file

run one of the 4 available macros:

TIN - For TIN generation

CN - For Contour Lines

ALIG - For alignment of 2D Polylines

VERT - For vertical views of 3D Polylines
