// Gurobi stub implementations for OR-Tools when Gurobi is not available
// This file provides dummy implementations for all Gurobi function pointers
// that OR-Tools expects, allowing the library to link without Gurobi installed.

#include <functional>

// Forward declarations from gurobi_c.h
extern "C" {
typedef struct _GRBmodel GRBmodel;
typedef struct _GRBenv GRBenv;
typedef struct _GRBsvec {
  int len;
  int* ind;
  double* val;
} GRBsvec;
}

#if defined(_MSC_VER)
#define GUROBI_STDCALL __stdcall
#else
#define GUROBI_STDCALL
#endif

#define CB_ARGS GRBmodel *model, void *cbdata, int where, void *usrdata
#define LOGCB_ARGS char *msg, void *logdata

// All Gurobi function pointers from environment.h - initialized to nullptr
namespace operations_research {
std::function<int(GRBmodel *model, const char *attrname)> GRBisattravailable = nullptr;
std::function<int(GRBmodel *model, const char *attrname, int *valueP)> GRBgetintattr = nullptr;
std::function<int(GRBmodel *model, const char *attrname, int newvalue)> GRBsetintattr = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, int *valueP)> GRBgetintattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, int newvalue)> GRBsetintattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, int *values)> GRBgetintattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, int *newvalues)> GRBsetintattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int len, int *ind, int *newvalues)> GRBsetintattrlist = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, char *valueP)> GRBgetcharattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, char newvalue)> GRBsetcharattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, char *values)> GRBgetcharattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, char *newvalues)> GRBsetcharattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int len, int *ind, char *newvalues)> GRBsetcharattrlist = nullptr;
std::function<int(GRBmodel *model, const char *attrname, double *valueP)> GRBgetdblattr = nullptr;
std::function<int(GRBmodel *model, const char *attrname, double newvalue)> GRBsetdblattr = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, double *valueP)> GRBgetdblattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int element, double newvalue)> GRBsetdblattrelement = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, double *values)> GRBgetdblattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int first, int len, double *newvalues)> GRBsetdblattrarray = nullptr;
std::function<int(GRBmodel *model, const char *attrname,int len, int *ind, double *newvalues)> GRBsetdblattrlist = nullptr;
std::function<int(GRBmodel *model, const char *attrname, char **valueP)> GRBgetstrattr = nullptr;
std::function<int(GRBmodel *model, const char *attrname, const char *newvalue)> GRBsetstrattr = nullptr;
std::function<int(GRBmodel *model,int (GUROBI_STDCALL *cb)(CB_ARGS),void  *usrdata)> GRBsetcallbackfunc = nullptr;
std::function<int(void *cbdata, int where, int what, void *resultP)> GRBcbget = nullptr;
std::function<int(void *cbdata, const double *solution, double *objvalP)> GRBcbsolution = nullptr;
std::function<int(void *cbdata, int cutlen, const int *cutind, const double *cutval,char cutsense, double cutrhs)> GRBcbcut = nullptr;
std::function<int(void *cbdata, int lazylen, const int *lazyind,const double *lazyval, char lazysense, double lazyrhs)> GRBcblazy = nullptr;
std::function<int(GRBmodel *model, int *numnzP, int *vbeg, int *vind,double *vval, int start, int len)> GRBgetvars = nullptr;
std::function<int(GRBmodel *model)> GRBoptimize = nullptr;
std::function<int(GRBmodel *model)> GRBcomputeIIS = nullptr;
std::function<int(GRBmodel *model, const char *filename)> GRBwrite = nullptr;
std::function<int(GRBenv *env, GRBmodel **modelP, const char *Pname, int numvars,double *obj, double *lb, double *ub, char *vtype,char **varnames)> GRBnewmodel = nullptr;
std::function<int(GRBmodel *model, int numnz, int *vind, double *vval,double obj, double lb, double ub, char vtype,const char *varname)> GRBaddvar = nullptr;
std::function<int(GRBmodel *model, int numvars, int numnz,int *vbeg, int *vind, double *vval,double *obj, double *lb, double *ub, char *vtype,char **varnames)> GRBaddvars = nullptr;
std::function<int(GRBmodel *model, int numnz, int *cind, double *cval,char sense, double rhs, const char *constrname)> GRBaddconstr = nullptr;
std::function<int(GRBmodel *model, int numconstrs, int numnz,int *cbeg, int *cind, double *cval,char *sense, double *rhs, char **constrnames)> GRBaddconstrs = nullptr;
std::function<int(GRBmodel *model, int numnz, int *cind, double *cval,double lower, double upper, const char *constrname)> GRBaddrangeconstr = nullptr;
std::function<int(GRBmodel *model, int numsos, int nummembers, int *types,int *beg, int *ind, double *weight)> GRBaddsos = nullptr;
std::function<int(GRBmodel *model, const char *name,int resvar, int nvars, const int *vars,double constant)> GRBaddgenconstrMax = nullptr;
std::function<int(GRBmodel *model, const char *name,int resvar, int nvars, const int *vars,double constant)> GRBaddgenconstrMin = nullptr;
std::function<int(GRBmodel *model, const char *name,int resvar, int argvar)> GRBaddgenconstrAbs = nullptr;
std::function<int(GRBmodel *model, const char *name,int resvar, int nvars, const int *vars)> GRBaddgenconstrAnd = nullptr;
std::function<int(GRBmodel *model, const char *name,int resvar, int nvars, const int *vars)> GRBaddgenconstrOr = nullptr;
std::function<int(GRBmodel *model, const char *name,int binvar, int binval, int nvars, const int *vars,const double *vals, char sense, double rhs)> GRBaddgenconstrIndicator = nullptr;
std::function<int(GRBmodel *model, int numlnz, int *lind, double *lval,int numqnz, int *qrow, int *qcol, double *qval,char sense, double rhs, const char *QCname)> GRBaddqconstr = nullptr;
std::function<int(GRBmodel *model, int numqnz, int *qrow, int *qcol,double *qval)> GRBaddqpterms = nullptr;
std::function<int(GRBmodel *model, int len, int *ind)> GRBdelvars = nullptr;
std::function<int(GRBmodel *model, int len, int *ind)> GRBdelconstrs = nullptr;
std::function<int(GRBmodel *model, int len, int *ind)> GRBdelsos = nullptr;
std::function<int(GRBmodel *model, int len, int *ind)> GRBdelgenconstrs = nullptr;
std::function<int(GRBmodel *model, int len, int *ind)> GRBdelqconstrs = nullptr;
std::function<int(GRBmodel *model)> GRBdelq = nullptr;
std::function<int(GRBmodel *model, int cnt, int *cind, int *vind, double *val)> GRBchgcoeffs = nullptr;
std::function<int(GRBmodel *model)> GRBupdatemodel = nullptr;
std::function<int(GRBmodel *model)> GRBfreemodel = nullptr;
std::function<void(GRBmodel *model)> GRBterminate = nullptr;
std::function<int(GRBmodel *model, int index, int priority, double weight,double abstol, double reltol, const char *name,double constant, int lnz, int *lind, double *lval)> GRBsetobjectiven = nullptr;
std::function<int(GRBenv *env, const char *paramname, int *valueP)> GRBgetintparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, double *valueP)> GRBgetdblparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, char *valueP)> GRBgetstrparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, const char *value)> GRBsetparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, int value)> GRBsetintparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, double value)> GRBsetdblparam = nullptr;
std::function<int(GRBenv *env, const char *paramname, const char *value)> GRBsetstrparam = nullptr;
std::function<int(GRBenv *env)> GRBresetparams = nullptr;
std::function<int(GRBenv *dest, GRBenv *src)> GRBcopyparams = nullptr;
std::function<int(GRBenv **envP, const char *logfilename)> GRBloadenv = nullptr;
std::function<int(GRBenv *env)> GRBstartenv = nullptr;
std::function<int(GRBenv **envP)> GRBemptyenv = nullptr;
std::function<int(GRBenv *envP)> GRBgetnumparams = nullptr;
std::function<int(GRBenv *envP, int i, char **paramnameP)> GRBgetparamname = nullptr;
std::function<int(GRBenv *envP, const char *paramname)> GRBgetparamtype = nullptr;
std::function<int(GRBenv *envP, const char *paramname, int *valueP, int *minP, int *maxP, int *defP)> GRBgetintparaminfo = nullptr;
std::function<int(GRBenv *envP, const char *paramname, double *valueP, double *minP, double *maxP, double *defP)> GRBgetdblparaminfo = nullptr;
std::function<int(GRBenv *envP, const char *paramname, char *valueP, char *defP)> GRBgetstrparaminfo = nullptr;
std::function<GRBenv *(GRBmodel *model)> GRBgetenv = nullptr;
std::function<GRBenv*(GRBmodel* model, int num)> GRBgetmultiobjenv = nullptr;
std::function<GRBenv*(GRBmodel* model)> GRBdiscardmultiobjenvs = nullptr;
std::function<void(GRBenv *env)> GRBfreeenv = nullptr;
std::function<const char *(GRBenv *env)> GRBgeterrormsg = nullptr;
std::function<void(int *majorP, int *minorP, int *technicalP)> GRBversion = nullptr;
std::function<char *(void)> GRBplatform = nullptr;
} // namespace operations_research
