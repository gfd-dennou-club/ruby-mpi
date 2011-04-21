#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include "ruby.h"
#include "narray.h"
#include "mpi.h"


#define OBJ2C(rb_obj, len, buffer, type) \
  if (TYPE(rb_obj) == T_STRING) {\
    len = RSTRING_LEN(rb_obj);\
    buffer = (void*)StringValuePtr(rb_obj);\
    type = MPI_CHAR;\
  } else if (IsNArray(rb_obj)) {		\
    struct NARRAY *a;\
    GetNArray(rb_obj, a);\
    buffer = (void*)(a->ptr);\
    len = a->total;\
    switch (a->type) {\
    case NA_BYTE:\
      type = MPI_BYTE;\
      break;\
    case NA_SINT:\
      type = MPI_SHORT;\
      break;\
    case NA_LINT:\
      type = MPI_LONG;\
      break;\
    case NA_SFLOAT:\
      type = MPI_FLOAT;\
      break;\
    case NA_DFLOAT:\
      type = MPI_DOUBLE;\
      break;\
    case NA_SCOMPLEX:\
      type = MPI_2COMPLEX;\
      break;\
    case NA_DCOMPLEX:\
      type = MPI_2DOUBLE_COMPLEX;\
      break;\
    default:\
      rb_raise(rb_eArgError, "narray type is invalid");\
    }\
  } else {\
    rb_raise(rb_eArgError, "Only String and NArray are supported");\
  }

static VALUE mMPI;
static VALUE cComm;
static VALUE cStatus;

static bool _initialized = false;
static bool _finalized = false;


static VALUE
rb_m_init(int argc, VALUE *argv, VALUE self)
{
  VALUE argary;
  int cargc;
  char ** cargv;
  VALUE progname;
  int i;

  if (_initialized)
    return self;
  else
    _initialized = true;

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

  MPI_Init(&cargc, &cargv);

  return self;
}

static void
_finalize()
{
  if(_initialized && !_finalized) {
    _finalized = true;
    MPI_Finalize();
  }
}
static VALUE
rb_m_finalize(VALUE self)
{
  _finalize();
  return self;
}


// MPI::Comm
static struct _Comm {
  MPI_Comm comm;
};
static VALUE
rb_comm_alloc(VALUE klass)
{
  struct _Comm *ptr = ALLOC(struct _Comm);
  return Data_Wrap_Struct(klass, 0, -1, ptr);
}
static VALUE
rb_comm_initialize(VALUE self)
{
  rb_raise(rb_eRuntimeError, "not developed yet");
  // MPI_Comm_create()
}
static VALUE
rb_comm_size(VALUE self)
{
  struct _Comm *comm;
  int size;
  Data_Get_Struct(self, struct _Comm, comm);
  MPI_Comm_size(comm->comm, &size);
  return INT2NUM(size);
}
static VALUE
rb_comm_rank(VALUE self)
{
  struct _Comm *comm;
  int rank;
  Data_Get_Struct(self, struct _Comm, comm);
  MPI_Comm_rank(comm->comm, &rank);
  return INT2NUM(rank);
}
static VALUE
rb_comm_send(VALUE self, VALUE rb_obj, VALUE rb_dest, VALUE rb_tag)
{
  void* buffer;
  int len, dest, tag;
  MPI_Datatype type;
  struct _Comm *comm;
  int ret;

  OBJ2C(rb_obj, len, buffer, type);
  dest = NUM2INT(rb_dest);
  tag = NUM2INT(rb_tag);
  Data_Get_Struct(self, struct _Comm, comm);
  ret = MPI_Send(buffer, len, type, dest, tag, comm->comm);

  return INT2NUM(ret);
}
static VALUE
rb_comm_recv(VALUE self, VALUE rb_obj, VALUE rb_source, VALUE rb_tag)
{
  void* buffer;
  int len, source, tag;
  MPI_Datatype type;
  MPI_Status *status;
  struct _Comm *comm;
  int ret;

  OBJ2C(rb_obj, len, buffer, type);
  source = NUM2INT(rb_source);
  tag = NUM2INT(rb_tag);

  Data_Get_Struct(self, struct _Comm, comm);
  status = ALLOC(MPI_Status);
  ret = MPI_Recv(buffer, len, type, source, tag, comm->comm, status);

  return rb_ary_new3(2, INT2NUM(ret), Data_Wrap_Struct(cStatus, 0, -1, status));
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

  atexit(_finalize);

  // MPI
  mMPI = rb_define_module("MPI");
  rb_define_module_function(mMPI, "Init", rb_m_init, -1);
  rb_define_module_function(mMPI, "Finalize", rb_m_finalize, -1);
  rb_define_const(mMPI, "VERSION", MPI_VERSION);
  rb_define_const(mMPI, "SUBVERSION", MPI_SUBVERSION);

  // MPI::Comm
  cComm = rb_define_class_under(mMPI, "Comm", rb_cObject);
  struct _Comm *world;
  world = ALLOC(struct _Comm);
  world->comm = MPI_COMM_WORLD;
  rb_define_const(cComm, "WORLD", Data_Wrap_Struct(cComm, 0, -1, world));
//  rb_define_alloc_func(cComm, rb_comm_alloc);
  rb_define_private_method(cComm, "initialize", rb_comm_initialize, 0);
  rb_define_method(cComm, "rank", rb_comm_rank, 0);
  rb_define_method(cComm, "size", rb_comm_size, 0);
  rb_define_method(cComm, "Send", rb_comm_send, 3);
  rb_define_method(cComm, "Recv", rb_comm_recv, 3);

  // MPI::Status
  cStatus = rb_define_class_under(mMPI, "Status", rb_cObject);
  rb_define_method(cStatus, "source", rb_status_source, 0);
  rb_define_method(cStatus, "tag", rb_status_tag, 0);
  rb_define_method(cStatus, "error", rb_status_error, 0);
}
