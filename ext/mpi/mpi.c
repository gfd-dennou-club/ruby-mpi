#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include "ruby.h"
#include "narray.h"
#include "mpi.h"


#define OBJ2C(rb_obj, len, buffer, typ) \
{\
  if (TYPE(rb_obj) == T_STRING) {\
    len = RSTRING_LEN(rb_obj);\
    buffer = (void*)StringValuePtr(rb_obj);\
    typ = MPI_CHAR;\
  } else if (IsNArray(rb_obj)) {		\
    struct NARRAY *a;\
    GetNArray(rb_obj, a);\
    buffer = (void*)(a->ptr);\
    len = a->total;\
    switch (a->type) {\
    case NA_BYTE:\
      typ = MPI_BYTE;\
      break;\
    case NA_SINT:\
      typ = MPI_SHORT;\
      break;\
    case NA_LINT:\
      typ = MPI_LONG;\
      break;\
    case NA_SFLOAT:\
      typ = MPI_FLOAT;\
      break;\
    case NA_DFLOAT:\
      typ = MPI_DOUBLE;\
      break;\
    case NA_SCOMPLEX:\
      typ = MPI_2COMPLEX;\
      break;\
    case NA_DCOMPLEX:\
      typ = MPI_2DOUBLE_COMPLEX;\
      break;\
    default:\
      rb_raise(rb_eArgError, "narray type is invalid");\
    }\
  } else {\
    rb_raise(rb_eArgError, "Only String and NArray are supported");\
  }\
}

static VALUE mMPI;
static VALUE cComm, cRequest, cOp, cErrhandler, cStatus;

static VALUE eBUFFER, eCOUNT, eTYPE, eTAG, eCOMM, eRANK, eREQUEST, eROOT, eGROUP, eOP, eTOPOLOGY, eDIMS, eARG, eUNKNOWN, eTRUNCATE, eOTHER, eINTERN, eIN_STATUS, ePENDING, eACCESS, eAMODE, eASSERT, eBAD_FILE, eBASE, eCONVERSION, eDISP, eDUP_DATAREP, eFILE_EXISTS, eFILE_IN_USE, eFILE, eINFO_KEY, eINFO_NOKEY, eINFO_VALUE, eINFO, eIO, eKEYVAL, eLOCKTYPE, eNAME, eNO_MEM, eNOT_SAME, eNO_SPACE, eNO_SUCH_FILE, ePORT, eQUOTA, eREAD_ONLY, eRMA_CONFLICT, eRMA_SYNC, eSERVICE, eSIZE, eSPAWN, eUNSUPPORTED_DATAREP, eUNSUPPORTED_OPERATION, eWIN, eLASTCODE, eSYSRESOURCE;

struct _Comm {
  MPI_Comm Comm;
  bool free;
};
struct _Request {
  MPI_Request Request;
  bool free;
};
struct _Op {
  MPI_Op Op;
  bool free;
};
struct _Errhandler {
  MPI_Errhandler Errhandler;
  bool free;
};

static bool _initialized = false;
static bool _finalized = false;


#define DEF_FREE(name) \
static void \
name ## _free(void *ptr)\
{\
  struct _ ## name *obj;\
  obj = (struct _ ## name*) ptr;\
  if (!_finalized && obj->free)\
    MPI_ ## name ## _free(&(obj->name)); \
  free(obj);\
}
DEF_FREE(Comm)
DEF_FREE(Request)
DEF_FREE(Op)
DEF_FREE(Errhandler)
static void
Status_free(void *ptr)
{
  free((MPI_Status*) ptr);
}


#define CAE_ERR(type) case MPI_ERR_ ## type: rb_raise(e ## type,"%s",str); break
static void
check_error(int error)
{
  if (error == MPI_SUCCESS) return;
  int code, len;
  char str[MPI_MAX_ERROR_STRING];
  if (MPI_Error_class(error, &code)!=MPI_SUCCESS || MPI_Error_string(error, str, &len)!=MPI_SUCCESS)
    rb_raise(rb_eRuntimeError, "unknown error occuerd in MPI call");

  switch (code) {
    CAE_ERR(BUFFER);
    CAE_ERR(COUNT);
    CAE_ERR(TYPE);
    CAE_ERR(TAG);
    CAE_ERR(COMM);
    CAE_ERR(RANK);
    CAE_ERR(REQUEST);
    CAE_ERR(ROOT);
    CAE_ERR(GROUP);
    CAE_ERR(OP);
    CAE_ERR(TOPOLOGY);
    CAE_ERR(DIMS);
    CAE_ERR(ARG);
    CAE_ERR(UNKNOWN);
    CAE_ERR(TRUNCATE);
    CAE_ERR(OTHER);
    CAE_ERR(INTERN);
    CAE_ERR(IN_STATUS);
    CAE_ERR(PENDING);
    CAE_ERR(ACCESS);
    CAE_ERR(AMODE);
    CAE_ERR(ASSERT);
    CAE_ERR(BAD_FILE);
    CAE_ERR(BASE);
    CAE_ERR(CONVERSION);
    CAE_ERR(DISP);
    CAE_ERR(DUP_DATAREP);
    CAE_ERR(FILE_EXISTS);
    CAE_ERR(FILE_IN_USE);
    CAE_ERR(FILE);
    CAE_ERR(INFO_KEY);
    CAE_ERR(INFO_NOKEY);
    CAE_ERR(INFO_VALUE);
    CAE_ERR(INFO);
    CAE_ERR(IO);
    CAE_ERR(KEYVAL);
    CAE_ERR(LOCKTYPE);
    CAE_ERR(NAME);
    CAE_ERR(NO_MEM);
    CAE_ERR(NOT_SAME);
    CAE_ERR(NO_SPACE);
    CAE_ERR(NO_SUCH_FILE);
    CAE_ERR(PORT);
    CAE_ERR(QUOTA);
    CAE_ERR(READ_ONLY);
    CAE_ERR(RMA_CONFLICT);
    CAE_ERR(RMA_SYNC);
    CAE_ERR(SERVICE);
    CAE_ERR(SIZE);
    CAE_ERR(SPAWN);
    CAE_ERR(UNSUPPORTED_DATAREP);
    CAE_ERR(UNSUPPORTED_OPERATION);
    CAE_ERR(WIN);
    CAE_ERR(LASTCODE);
#ifdef MPI_ERR_SYSRESOURCE
    CAE_ERR(SYSRESOURCE);
#endif
  default:
    rb_raise(rb_eRuntimeError, "unknown error: %d", code);
  }
}

#define DEF_CONST(v, const, name) \
{\
  v = ALLOC(struct _ ## v);\
  v->v = const;\
  v->free = false;\
  rb_define_const(c ## v, #name, Data_Wrap_Struct(c ## v, NULL, v ## _free, v));	\
}

static void
_finalize()
{
  if(_initialized && !_finalized) {
    _finalized = true;
    check_error(MPI_Finalize());
  }
}
static VALUE
rb_m_init(int argc, VALUE *argv, VALUE self)
{
  VALUE argary;
  int cargc;
  char ** cargv;
  VALUE progname;
  int i;

  rb_scan_args(argc, argv, "01", &argary);

  if (NIL_P(argary)) {
    argary = rb_const_get(rb_cObject, rb_intern("ARGV"));
    cargc = RARRAY_LEN(argary);
  } else {
    Check_Type(argary, T_ARRAY);
    cargc = RARRAY_LEN(argary);
  }

  cargv = ALLOCA_N(char *, cargc+1);
  progname = rb_gv_get("$0");
  cargv[0] = StringValueCStr(progname);

  for(i=0; i<cargc; i++) {
    if (TYPE(RARRAY_PTR(argary)[i]) == T_STRING)
      cargv[i+1] = StringValueCStr(RARRAY_PTR(argary)[i]);
    else
      cargv[i+1] = (char*)"";
  }
  cargc++;

  check_error(MPI_Init(&cargc, &cargv));
  if (_initialized)
    return self;
  else
    _initialized = true;
  atexit(_finalize);



  // define MPI::Comm::WORLD
  struct _Comm *Comm;
  DEF_CONST(Comm, MPI_COMM_WORLD, WORLD);
  MPI_Errhandler_set(MPI_COMM_WORLD, MPI_ERRORS_RETURN);

  // define MPI::Op::???
  struct _Op *Op;
  DEF_CONST(Op, MPI_MAX, MAX);
  DEF_CONST(Op, MPI_MIN, MIN);
  DEF_CONST(Op, MPI_SUM, SUM);
  DEF_CONST(Op, MPI_PROD, PROD);
  DEF_CONST(Op, MPI_LAND, LAND);
  DEF_CONST(Op, MPI_BAND, BAND);
  DEF_CONST(Op, MPI_LOR, LOR);
  DEF_CONST(Op, MPI_BOR, BOR);
  DEF_CONST(Op, MPI_LXOR, LXOR);
  DEF_CONST(Op, MPI_BXOR, BXOR);
  DEF_CONST(Op, MPI_MAXLOC, MAXLOC);
  DEF_CONST(Op, MPI_MINLOC, MINLOC);
  DEF_CONST(Op, MPI_REPLACE, REPLACE);

  // define MPI::Errhandler::ERRORS_ARE_FATAL, ERRORS_RETURN
  struct _Errhandler *Errhandler;
  DEF_CONST(Errhandler, MPI_ERRORS_ARE_FATAL, ERRORS_ARE_FATAL);
  DEF_CONST(Errhandler, MPI_ERRORS_RETURN, ERRORS_RETURN);

  return self;
}

static VALUE
rb_m_finalize(VALUE self)
{
  _finalize();
  return self;
}


// MPI::Comm
static VALUE
rb_comm_alloc(VALUE klass)
{
  struct _Comm *ptr = ALLOC(struct _Comm);
  return Data_Wrap_Struct(klass, NULL, Comm_free, ptr);
}
static VALUE
rb_comm_initialize(VALUE self)
{
  rb_raise(rb_eRuntimeError, "not developed yet");
  // MPI_Comm_create()
  // comm->free = true;
}
static VALUE
rb_comm_size(VALUE self)
{
  struct _Comm *comm;
  int size;
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_size(comm->Comm, &size));
  return INT2NUM(size);
}
static VALUE
rb_comm_rank(VALUE self)
{
  struct _Comm *comm;
  int rank;
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  return INT2NUM(rank);
}
static VALUE
rb_comm_send(VALUE self, VALUE rb_obj, VALUE rb_dest, VALUE rb_tag)
{
  void* buffer;
  int len, dest, tag;
  MPI_Datatype type;
  struct _Comm *comm;

  OBJ2C(rb_obj, len, buffer, type);
  dest = NUM2INT(rb_dest);
  tag = NUM2INT(rb_tag);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Send(buffer, len, type, dest, tag, comm->Comm));

  return Qnil;
}
static VALUE
rb_comm_isend(VALUE self, VALUE rb_obj, VALUE rb_dest, VALUE rb_tag)
{
  void* buffer;
  int len, dest, tag;
  MPI_Datatype type;
  struct _Comm *comm;
  struct _Request *request;
  VALUE rb_request;

  OBJ2C(rb_obj, len, buffer, type);
  dest = NUM2INT(rb_dest);
  tag = NUM2INT(rb_tag);
  Data_Get_Struct(self, struct _Comm, comm);
  rb_request = Data_Make_Struct(cRequest, struct _Request, NULL, Request_free, request);
  request->free = true;
  check_error(MPI_Isend(buffer, len, type, dest, tag, comm->Comm, &(request->Request)));

  return rb_request;
}
static VALUE
rb_comm_recv(VALUE self, VALUE rb_obj, VALUE rb_source, VALUE rb_tag)
{
  void* buffer;
  int len, source, tag;
  MPI_Datatype type;
  MPI_Status *status;
  struct _Comm *comm;

  OBJ2C(rb_obj, len, buffer, type);
  source = NUM2INT(rb_source);
  tag = NUM2INT(rb_tag);

  Data_Get_Struct(self, struct _Comm, comm);
  status = ALLOC(MPI_Status);
  check_error(MPI_Recv(buffer, len, type, source, tag, comm->Comm, status));

  return Data_Wrap_Struct(cStatus, NULL, Status_free, status);
}
static VALUE
rb_comm_irecv(VALUE self, VALUE rb_obj, VALUE rb_source, VALUE rb_tag)
{
  void* buffer;
  int len, source, tag;
  MPI_Datatype type;
  struct _Comm *comm;
  struct _Request *request;
  VALUE rb_request;

  OBJ2C(rb_obj, len, buffer, type);
  source = NUM2INT(rb_source);
  tag = NUM2INT(rb_tag);
  Data_Get_Struct(self, struct _Comm, comm);
  rb_request = Data_Make_Struct(cRequest, struct _Request, NULL, Request_free, request);
  request->free = true;
  check_error(MPI_Irecv(buffer, len, type, source, tag, comm->Comm, &(request->Request)));

  return rb_request;
}
static VALUE
rb_comm_gather(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf, VALUE rb_root)
{
  void *sendbuf, *recvbuf = NULL;
  int sendcount, recvcount = 0;
  MPI_Datatype sendtype, recvtype = 0;
  int root, rank, size;
  struct _Comm *comm;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  root = NUM2INT(rb_root);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  check_error(MPI_Comm_size(comm->Comm, &size));
  if (rank == root) {
    OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
    if (recvcount < sendcount*size)
      rb_raise(rb_eArgError, "recvbuf is too small");
    recvcount = sendcount;
  }
  check_error(MPI_Gather(sendbuf, sendcount, sendtype, recvbuf, recvcount, recvtype, root, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_allgather(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf)
{
  void *sendbuf, *recvbuf;
  int sendcount, recvcount;
  MPI_Datatype sendtype, recvtype;
  int rank, size;
  struct _Comm *comm;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  check_error(MPI_Comm_size(comm->Comm, &size));
  OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
  if (recvcount < sendcount*size)
    rb_raise(rb_eArgError, "recvbuf is too small");
  recvcount = sendcount;
  check_error(MPI_Allgather(sendbuf, sendcount, sendtype, recvbuf, recvcount, recvtype, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_bcast(VALUE self, VALUE rb_buffer, VALUE rb_root)
{
  void *buffer;
  int count;
  MPI_Datatype type;
  int root;
  struct _Comm *comm;
  OBJ2C(rb_buffer, count, buffer, type);
  root = NUM2INT(rb_root);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Bcast(buffer, count, type, root, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_scatter(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf, VALUE rb_root)
{
  void *sendbuf = NULL, *recvbuf;
  int sendcount = 0, recvcount;
  MPI_Datatype sendtype = 0, recvtype;
  int root, rank, size;
  struct _Comm *comm;
  OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
  root = NUM2INT(rb_root);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  check_error(MPI_Comm_size(comm->Comm, &size));
  if (rank == root) {
    OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
    if (sendcount > recvcount*size)
      rb_raise(rb_eArgError, "recvbuf is too small");
    sendcount = recvcount;
  }
  check_error(MPI_Scatter(sendbuf, sendcount, sendtype, recvbuf, recvcount, recvtype, root, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_sendrecv(VALUE self, VALUE rb_sendbuf, VALUE rb_dest, VALUE rb_sendtag, VALUE rb_recvbuf, VALUE rb_source, VALUE rb_recvtag)
{
  void *sendbuf, *recvbuf;
  int sendcount, recvcount;
  MPI_Datatype sendtype, recvtype;
  int dest, source;
  int sendtag, recvtag;
  int size;
  struct _Comm *comm;
  MPI_Status *status;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_size(comm->Comm, &size));
  OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
  dest = NUM2INT(rb_dest);
  source = NUM2INT(rb_source);
  sendtag = NUM2INT(rb_sendtag);
  recvtag = NUM2INT(rb_recvtag);
  status = ALLOC(MPI_Status);
  check_error(MPI_Sendrecv(sendbuf, sendcount, sendtype, dest, sendtag, recvbuf, recvcount, recvtype, source, recvtag, comm->Comm, status));
  return Data_Wrap_Struct(cStatus, NULL, Status_free, status);
}
static VALUE
rb_comm_alltoall(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf)
{
  void *sendbuf, *recvbuf;
  int sendcount, recvcount;
  MPI_Datatype sendtype, recvtype;
  int size;
  struct _Comm *comm;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_size(comm->Comm, &size));
  OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
  if (recvcount < sendcount)
    rb_raise(rb_eArgError, "recvbuf is too small");
  recvcount = recvcount/size;
  sendcount = sendcount/size;
  check_error(MPI_Alltoall(sendbuf, sendcount, sendtype, recvbuf, recvcount, recvtype, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_reduce(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf, VALUE rb_op, VALUE rb_root)
{
  void *sendbuf, *recvbuf = NULL;
  int sendcount, recvcount = 0;
  MPI_Datatype sendtype, recvtype = 0;
  int root, rank, size;
  struct _Comm *comm;
  struct _Op *op;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  root = NUM2INT(rb_root);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  check_error(MPI_Comm_size(comm->Comm, &size));
  if (rank == root) {
    OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
    if (recvcount != sendcount)
      rb_raise(rb_eArgError, "sendbuf and recvbuf has the same length");
    if (recvtype != sendtype)
      rb_raise(rb_eArgError, "sendbuf and recvbuf has the same type");
  }
  Data_Get_Struct(rb_op, struct _Op, op);
  check_error(MPI_Reduce(sendbuf, recvbuf, sendcount, sendtype, op->Op, root, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_allreduce(VALUE self, VALUE rb_sendbuf, VALUE rb_recvbuf, VALUE rb_op)
{
  void *sendbuf, *recvbuf;
  int sendcount, recvcount;
  MPI_Datatype sendtype, recvtype;
  int rank, size;
  struct _Comm *comm;
  struct _Op *op;
  OBJ2C(rb_sendbuf, sendcount, sendbuf, sendtype);
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Comm_rank(comm->Comm, &rank));
  check_error(MPI_Comm_size(comm->Comm, &size));
  OBJ2C(rb_recvbuf, recvcount, recvbuf, recvtype);
  if (recvcount != sendcount)
    rb_raise(rb_eArgError, "sendbuf and recvbuf has the same length");
  if (recvtype != sendtype)
    rb_raise(rb_eArgError, "sendbuf and recvbuf has the same type");
  Data_Get_Struct(rb_op, struct _Op, op);
  check_error(MPI_Allreduce(sendbuf, recvbuf, recvcount, recvtype, op->Op, comm->Comm));
  return Qnil;
}
static VALUE
rb_comm_get_Errhandler(VALUE self)
{
  struct _Comm *comm;
  struct _Errhandler *errhandler;
  VALUE rb_errhandler;

  Data_Get_Struct(self, struct _Comm, comm);
  rb_errhandler = Data_Make_Struct(cErrhandler, struct _Errhandler, NULL, Errhandler_free, errhandler);
  errhandler->free = false;
  MPI_Comm_get_errhandler(comm->Comm, &(errhandler->Errhandler));
  return rb_errhandler;
}
static VALUE
rb_comm_set_Errhandler(VALUE self, VALUE rb_errhandler)
{
  struct _Comm *comm;
  struct _Errhandler *errhandler;

  Data_Get_Struct(self, struct _Comm, comm);
  Data_Get_Struct(rb_errhandler, struct _Errhandler, errhandler);
  MPI_Comm_set_errhandler(comm->Comm, errhandler->Errhandler);
  return self;
}
static VALUE
rb_comm_barrier(VALUE self)
{
  struct _Comm *comm;
  Data_Get_Struct(self, struct _Comm, comm);
  check_error(MPI_Barrier(comm->Comm));
  return self;
}

// MPI::Request
static VALUE
rb_request_wait(VALUE self)
{
  MPI_Status *status;
  struct _Request *request;
  Data_Get_Struct(self, struct _Request, request);
  status = ALLOC(MPI_Status);
  check_error(MPI_Wait(&(request->Request), status));
  return Data_Wrap_Struct(cStatus, NULL, Status_free, status);
}

// MPI::Errhandler
static VALUE
rb_errhandler_eql(VALUE self, VALUE other)
{
  struct _Errhandler *eh0, *eh1;
  Data_Get_Struct(self, struct _Errhandler, eh0);
  Data_Get_Struct(other, struct _Errhandler, eh1);
  return eh0->Errhandler == eh1->Errhandler ? Qtrue : Qfalse;
}

// MPI::Status
static VALUE
rb_status_source(VALUE self)
{
  MPI_Status *status;
  Data_Get_Struct(self, MPI_Status, status);
  return INT2NUM(status->MPI_SOURCE);
}
static VALUE
rb_status_tag(VALUE self)
{
  MPI_Status *status;
  Data_Get_Struct(self, MPI_Status, status);
  return INT2NUM(status->MPI_TAG);
}
static VALUE
rb_status_error(VALUE self)
{
  MPI_Status *status;
  Data_Get_Struct(self, MPI_Status, status);
  return INT2NUM(status->MPI_ERROR);
}


void Init_mpi()
{

  rb_require("narray");

  // MPI
  mMPI = rb_define_module("MPI");
  rb_define_module_function(mMPI, "Init", rb_m_init, -1);
  rb_define_module_function(mMPI, "Finalize", rb_m_finalize, -1);
  rb_define_const(mMPI, "VERSION", INT2NUM(MPI_VERSION));
  rb_define_const(mMPI, "SUBVERSION", INT2NUM(MPI_SUBVERSION));
  rb_define_const(mMPI, "SUCCESS", INT2NUM(MPI_SUCCESS));
  rb_define_const(mMPI, "PROC_NULL", INT2NUM(MPI_PROC_NULL));

  // MPI::Comm
  cComm = rb_define_class_under(mMPI, "Comm", rb_cObject);
//  rb_define_alloc_func(cComm, rb_comm_alloc);
  rb_define_private_method(cComm, "initialize", rb_comm_initialize, 0);
  rb_define_method(cComm, "rank", rb_comm_rank, 0);
  rb_define_method(cComm, "size", rb_comm_size, 0);
  rb_define_method(cComm, "Send", rb_comm_send, 3);
  rb_define_method(cComm, "Isend", rb_comm_isend, 3);
  rb_define_method(cComm, "Recv", rb_comm_recv, 3);
  rb_define_method(cComm, "Irecv", rb_comm_irecv, 3);
  rb_define_method(cComm, "Gather", rb_comm_gather, 3);
  rb_define_method(cComm, "Allgather", rb_comm_allgather, 2);
  rb_define_method(cComm, "Bcast", rb_comm_bcast, 2);
  rb_define_method(cComm, "Scatter", rb_comm_scatter, 3);
  rb_define_method(cComm, "Sendrecv", rb_comm_sendrecv, 6);
  rb_define_method(cComm, "Alltoall", rb_comm_alltoall, 2);
  rb_define_method(cComm, "Reduce", rb_comm_reduce, 4);
  rb_define_method(cComm, "Allreduce", rb_comm_allreduce, 3);
  rb_define_method(cComm, "Errhandler", rb_comm_get_Errhandler, 0);
  rb_define_method(cComm, "Errhandler=", rb_comm_set_Errhandler, 1);
  rb_define_method(cComm, "Barrier", rb_comm_barrier, 0);

  // MPI::Request
  cRequest = rb_define_class_under(mMPI, "Request", rb_cObject);
  rb_define_method(cRequest, "Wait", rb_request_wait, 0);

  // MPI::Op
  cOp = rb_define_class_under(mMPI, "Op", rb_cObject);

  // MPI::Errhandler
  cErrhandler = rb_define_class_under(mMPI, "Errhandler", rb_cObject);
  rb_define_method(cErrhandler, "eql?", rb_errhandler_eql, 1);

  // MPI::Status
  cStatus = rb_define_class_under(mMPI, "Status", rb_cObject);
  rb_define_method(cStatus, "source", rb_status_source, 0);
  rb_define_method(cStatus, "tag", rb_status_tag, 0);
  rb_define_method(cStatus, "error", rb_status_error, 0);


  //MPI::ERR
  VALUE mERR = rb_define_module_under(mMPI, "ERR");
  eBUFFER = rb_define_class_under(mERR, "BUFFER", rb_eStandardError);
  eCOUNT = rb_define_class_under(mERR, "COUNT", rb_eStandardError);
  eTYPE = rb_define_class_under(mERR, "TYPE", rb_eStandardError);
  eTAG = rb_define_class_under(mERR, "TAG", rb_eStandardError);
  eCOMM = rb_define_class_under(mERR, "COMM", rb_eStandardError);
  eRANK = rb_define_class_under(mERR, "RANK", rb_eStandardError);
  eREQUEST = rb_define_class_under(mERR, "REQUEST", rb_eStandardError);
  eROOT = rb_define_class_under(mERR, "ROOT", rb_eStandardError);
  eGROUP = rb_define_class_under(mERR, "GROUP", rb_eStandardError);
  eOP = rb_define_class_under(mERR, "OP", rb_eStandardError);
  eTOPOLOGY = rb_define_class_under(mERR, "TOPOLOGY", rb_eStandardError);
  eDIMS = rb_define_class_under(mERR, "DIMS", rb_eStandardError);
  eARG = rb_define_class_under(mERR, "ARG", rb_eStandardError);
  eUNKNOWN = rb_define_class_under(mERR, "UNKNOWN", rb_eStandardError);
  eTRUNCATE = rb_define_class_under(mERR, "TRUNCATE", rb_eStandardError);
  eOTHER = rb_define_class_under(mERR, "OTHER", rb_eStandardError);
  eINTERN = rb_define_class_under(mERR, "INTERN", rb_eStandardError);
  eIN_STATUS = rb_define_class_under(mERR, "IN_STATUS", rb_eStandardError);
  ePENDING = rb_define_class_under(mERR, "PENDING", rb_eStandardError);
  eACCESS = rb_define_class_under(mERR, "ACCESS", rb_eStandardError);
  eAMODE = rb_define_class_under(mERR, "AMODE", rb_eStandardError);
  eASSERT = rb_define_class_under(mERR, "ASSERT", rb_eStandardError);
  eBAD_FILE = rb_define_class_under(mERR, "BAD_FILE", rb_eStandardError);
  eBASE = rb_define_class_under(mERR, "BASE", rb_eStandardError);
  eCONVERSION = rb_define_class_under(mERR, "CONVERSION", rb_eStandardError);
  eDISP = rb_define_class_under(mERR, "DISP", rb_eStandardError);
  eDUP_DATAREP = rb_define_class_under(mERR, "DUP_DATAREP", rb_eStandardError);
  eFILE_EXISTS = rb_define_class_under(mERR, "FILE_EXISTS", rb_eStandardError);
  eFILE_IN_USE = rb_define_class_under(mERR, "FILE_IN_USE", rb_eStandardError);
  eFILE = rb_define_class_under(mERR, "FILE", rb_eStandardError);
  eINFO_KEY = rb_define_class_under(mERR, "INFO_KEY", rb_eStandardError);
  eINFO_NOKEY = rb_define_class_under(mERR, "INFO_NOKEY", rb_eStandardError);
  eINFO_VALUE = rb_define_class_under(mERR, "INFO_VALUE", rb_eStandardError);
  eINFO = rb_define_class_under(mERR, "INFO", rb_eStandardError);
  eIO = rb_define_class_under(mERR, "IO", rb_eStandardError);
  eKEYVAL = rb_define_class_under(mERR, "KEYVAL", rb_eStandardError);
  eLOCKTYPE = rb_define_class_under(mERR, "LOCKTYPE", rb_eStandardError);
  eNAME = rb_define_class_under(mERR, "NAME", rb_eStandardError);
  eNO_MEM = rb_define_class_under(mERR, "NO_MEM", rb_eStandardError);
  eNOT_SAME = rb_define_class_under(mERR, "NOT_SAME", rb_eStandardError);
  eNO_SPACE = rb_define_class_under(mERR, "NO_SPACE", rb_eStandardError);
  eNO_SUCH_FILE = rb_define_class_under(mERR, "NO_SUCH_FILE", rb_eStandardError);
  ePORT = rb_define_class_under(mERR, "PORT", rb_eStandardError);
  eQUOTA = rb_define_class_under(mERR, "QUOTA", rb_eStandardError);
  eREAD_ONLY = rb_define_class_under(mERR, "READ_ONLY", rb_eStandardError);
  eRMA_CONFLICT = rb_define_class_under(mERR, "RMA_CONFLICT", rb_eStandardError);
  eRMA_SYNC = rb_define_class_under(mERR, "RMA_SYNC", rb_eStandardError);
  eSERVICE = rb_define_class_under(mERR, "SERVICE", rb_eStandardError);
  eSIZE = rb_define_class_under(mERR, "SIZE", rb_eStandardError);
  eSPAWN = rb_define_class_under(mERR, "SPAWN", rb_eStandardError);
  eUNSUPPORTED_DATAREP = rb_define_class_under(mERR, "UNSUPPORTED_DATAREP", rb_eStandardError);
  eUNSUPPORTED_OPERATION = rb_define_class_under(mERR, "UNSUPPORTED_OPERATION", rb_eStandardError);
  eWIN = rb_define_class_under(mERR, "WIN", rb_eStandardError);
  eLASTCODE = rb_define_class_under(mERR, "LASTCODE", rb_eStandardError);
  eSYSRESOURCE = rb_define_class_under(mERR, "SYSRESOURCE", rb_eStandardError);
}
