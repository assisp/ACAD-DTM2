#include <windows.h>
#include <stdlib.h>
#include <cmath>
#include <vector>
#include "include/CDT.h"

/*
 *  DEFINITIONS
 */
using Triangulation = CDT::Triangulation<double>;
using V2d = CDT::V2d<double>;
using Edge = CDT::Edge;
using Triangle = CDT::Triangle;

const double fuzz = 0.0001;

class DTM {
private:
	std::vector<V2d> m_pts;
	std::vector<Edge> m_edges;
	Triangulation cdt = Triangulation(CDT::FindingClosestPoint::BoostRTree);
	int orientation(unsigned long v1, unsigned long v2, unsigned long v3);
public:
	DTM();
	~DTM();
	unsigned long AddPoint(double x, double y, double z);
	unsigned long AppendPoint(double x, double y, double z);
	unsigned long PointListSize(){return m_pts.size();};
	const V2d& GetPoint(unsigned long index);
	unsigned long GetPointIndex(double x, double y);
	unsigned long AddEdgeConstraint(double x1, double y1, double x2, double y2);
	unsigned long AddConstraint(unsigned long v1, unsigned long v2);
	unsigned long Triangulate();
	unsigned long TriangleListSize() {return cdt.triangles.size();};
	bool GetTriangle(unsigned long index, double* p1, double* p2, double* p3);
};

/*
 *   IMPLEMENTATION
 */

/*
 * DTM class
 */

DTM::DTM(){
}

DTM::~DTM(){
	m_pts.clear();
	m_edges.clear();
}

unsigned long DTM::AddPoint(double x, double y, double z) {
	std::vector<V2d>::const_iterator it;
	
	const V2d p = {x, y, z};

	if (m_pts.empty())
	{
		m_pts.push_back(p);
		return m_pts.size();
	}
	
	for (it=m_pts.begin(); it!=m_pts.end(); ++it) {
		if (p.x < it->x) {
			m_pts.insert(it, p);
			return m_pts.size();
		} else {
			if ( p.x <= it->x + fuzz and p.x > it->x - fuzz and p.y < it->y) {
				m_pts.insert(it, p);
				return m_pts.size();
			} else {
				if ( p.x <= it->x + fuzz and p.x > it->x - fuzz and p.y <= it->y + fuzz and p.y > it->y - fuzz )
					return m_pts.size(); //duplicate - don't add point
			}
		}
	}

	m_pts.push_back(p);
	
	
	return m_pts.size();
}

unsigned long DTM::AppendPoint(double x, double y, double z) {
	const V2d p = {x, y, z};
	m_pts.push_back(p);

	return m_pts.size();
}

const V2d& DTM::GetPoint(unsigned long index){
	if (index < m_pts.size())
		return m_pts.at(index);
	
	return m_pts.at(m_pts.size() - 1);
}

unsigned long DTM::GetPointIndex(double x, double y){
	std::vector<V2d>::const_iterator it;
	unsigned long ind = 0;
	
	for (it=m_pts.begin(); it!=m_pts.end(); ++it) {
		if (x <= it->x + fuzz and x > it->x - fuzz and y <= it->y + fuzz and y > it->y - fuzz)
			return ind;

		ind++;
	}
	
	char buf[200];
	wsprintf(buf, "point (%f,%f) is not in point list", x, y);
	const int result = MessageBox(0, buf, "DTM Lib", MB_YESNOCANCEL);
	if (result == IDNO) 
	 	exit(0);
	return m_pts.size(); //point p is not in list
}

unsigned long DTM::AddEdgeConstraint(double x1, double y1, double x2, double y2){
	unsigned long v1 = GetPointIndex(x1, y1);
	unsigned long v2 = GetPointIndex(x2, y2);

	unsigned long e1 = v1 < v2 ? v1 : v2;
	unsigned long e2 = v1 < v2 ? v2 : v1;

	for (unsigned long ind = e1 + 1; ind < e2; ind++)
	{
		if (orientation(e1, e2 , ind) == 0) {
			AddConstraint(e1, ind);
			e1 = ind;		
		}
	}
	return AddConstraint(e1, e2);
}

unsigned long DTM::AddConstraint(unsigned long v1, unsigned long v2) {
	
	m_edges.push_back(Edge(v1, v2));
	
	return m_edges.size();
}

/*
 * To find orientation of ordered triplet(p1, p2, p3).Rem The function returns following values 
 * 0 -- > p1, p2 and p3 are colinear
 * 1 -- > Clockwise
 * 2 -- > Counterclockwise
*/
int DTM::orientation(unsigned long v1, unsigned long v2, unsigned long v3) {
	const V2d& p1 = GetPoint(v1);
	const V2d& p2 = GetPoint(v2);
	const V2d& p3 = GetPoint(v3);

	double val = ((p2.y - p1.y) * (p3.x - p2.x)) - ((p2.x - p1.x) * (p3.y - p2.y));

	if (val < -fuzz) {
		return 2;
	} else {
		if (val > fuzz) {
			return 1;
		}
	}

	return 0;
}

unsigned long DTM::Triangulate() {
	cdt.insertVertices(m_pts);
	cdt.insertEdges(m_edges);
	cdt.eraseSuperTriangle();

	return cdt.triangles.size();
}

bool DTM::GetTriangle(unsigned long index, double* p1, double* p2, double* p3) {

	if (index >= cdt.triangles.size())
		return false;

	const Triangle& t = cdt.triangles.at(index);

	//if(t.vertices[0] < 3 || t.vertices[1] < 3 || t.vertices[2] < 3) {
    //    return false;
    //}
    
    const V2d& v1 = cdt.vertices[t.vertices[0]].pos;
    const V2d& v2 = cdt.vertices[t.vertices[1]].pos;
    const V2d& v3 = cdt.vertices[t.vertices[2]].pos;

    p1[0] = v1.x;
    p1[1] = v1.y;
    p1[2] = v1.z;
    p2[0] = v2.x;
    p2[1] = v2.y;
    p2[2] = v2.z;
    p3[0] = v3.x;
    p3[1] = v3.y;
    p3[2] = v3.z;

    return true;
}

/*
 *    LIB exported functions
 */
extern "C" {

void* __declspec (dllexport) _stdcall DTMLib_init() {
	DTM *pdtm = new DTM;
	return (void *) pdtm;
}

void __declspec (dllexport) _stdcall DTMLib_close(void *handle) {
	DTM *pdtm = (DTM *) handle;
	delete (pdtm);
}

unsigned long __declspec (dllexport) _stdcall DTMLib_addPoint(void *handle, double x, double y, double z) {
	DTM *pdtm = (DTM *) handle;
	return pdtm->AddPoint(x, y, z);
}

unsigned long __declspec (dllexport) _stdcall DTMLib_appendPoint(void *handle, double x, double y, double z) {
	DTM *pdtm = (DTM *) handle;
	return pdtm->AppendPoint(x, y, z);
}

unsigned long __declspec (dllexport) _stdcall DTMLib_pointListSize(void *handle) {
	DTM *pdtm = (DTM *) handle;
	return pdtm->PointListSize();
}

void __declspec (dllexport) _stdcall DTMLib_getPoint(void *handle, unsigned long index, double *x, double *y, double *z) {
	DTM *pdtm = (DTM *) handle;
	const V2d& p = pdtm->GetPoint(index);
	
	*x = p.x;
	*y = p.y;
	*z = p.z;
}

unsigned long __declspec (dllexport) _stdcall DTMLib_addConstraint(void *handle, double x1, double y1, double x2, double y2) {
	DTM *pdtm = (DTM *) handle;

	return pdtm->AddEdgeConstraint(x1, y1, x2, y2);
}

unsigned long __declspec (dllexport) _stdcall DTMLib_triangulate(void *handle) {
	DTM *pdtm = (DTM *) handle;
	
	return pdtm->Triangulate();
}

bool __declspec (dllexport) _stdcall DTMLib_getTriangle(void *handle, unsigned long index, double *v1, double *v2, double *v3) {
	DTM *pdtm = (DTM *) handle;
	
	return pdtm->GetTriangle(index, v1, v2, v3);
}
	
}


