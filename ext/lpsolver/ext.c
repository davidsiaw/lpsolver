/*
 * lpsolver/native — HiGHS C API wrapper for Ruby
 *
 * Object-oriented wrapper: create a solver, set fields via setters,
 * then solve. Avoids passing large C arrays through Ruby's VM.
 *
 * Uses Highs_lpCall (flat single-shot API) from the official
 * HiGHS minimal example.
 *
 * Compatible with HiGHS v1.14.0 C API.
 */

#include <stdlib.h>
#include "ruby.h"
#include "interfaces/highs_c_api.h"

/* Opaque handle — stores a pointer to our internal state */
static VALUE rb_cHiGhSSolver;

typedef struct {
    HighsInt   num_col;
    HighsInt   num_row;
    HighsInt   num_nz;

    /* Column data */
    double    *col_cost;
    double    *col_lower;
    double    *col_upper;
    HighsInt  *col_integrality;

    /* Row data */
    double    *row_lower;
    double    *row_upper;

    /* Sparse matrix (CSC format) */
    HighsInt  *a_start;
    HighsInt  *a_index;
    double    *a_value;

    /* Solution buffers (allocated on solve) */
    double    *col_value;
    double    *col_dual;
    double    *row_value;
    double    *row_dual;
    HighsInt  *col_basis;
    HighsInt  *row_basis;

    /* Solver result */
    HighsInt  run_status;
    HighsInt  model_status;
    double    objective_value;
} HiGHSState;

static void state_free(HiGHSState *s) {
    if (!s) return;
    free(s->col_cost);
    free(s->col_lower);
    free(s->col_upper);
    free(s->col_integrality);
    free(s->row_lower);
    free(s->row_upper);
    free(s->a_start);
    free(s->a_index);
    free(s->a_value);
    free(s->col_value);
    free(s->col_dual);
    free(s->row_value);
    free(s->row_dual);
    free(s->col_basis);
    free(s->row_basis);
    free(s);
}

static HiGHSState *state_new(void) {
    HiGHSState *s = (HiGHSState*)calloc(1, sizeof(HiGHSState));
    return s;
}

static VALUE model_status_to_symbol(HighsInt status) {
    if (status == kHighsModelStatusNotset)               return ID2SYM(rb_intern("notset"));
    if (status == kHighsModelStatusLoadError)            return ID2SYM(rb_intern("load_error"));
    if (status == kHighsModelStatusModelError)           return ID2SYM(rb_intern("model_error"));
    if (status == kHighsModelStatusPresolveError)        return ID2SYM(rb_intern("presolve_error"));
    if (status == kHighsModelStatusSolveError)           return ID2SYM(rb_intern("solve_error"));
    if (status == kHighsModelStatusPostsolveError)       return ID2SYM(rb_intern("postsolve_error"));
    if (status == kHighsModelStatusModelEmpty)           return ID2SYM(rb_intern("model_empty"));
    if (status == kHighsModelStatusOptimal)              return ID2SYM(rb_intern("optimal"));
    if (status == kHighsModelStatusInfeasible)           return ID2SYM(rb_intern("infeasible"));
    if (status == kHighsModelStatusUnboundedOrInfeasible)return ID2SYM(rb_intern("unbounded_or_infeasible"));
    if (status == kHighsModelStatusUnbounded)            return ID2SYM(rb_intern("unbounded"));
    if (status == kHighsModelStatusObjectiveBound)       return ID2SYM(rb_intern("objective_bound"));
    if (status == kHighsModelStatusObjectiveTarget)      return ID2SYM(rb_intern("objective_target"));
    if (status == kHighsModelStatusTimeLimit)            return ID2SYM(rb_intern("time_limit"));
    if (status == kHighsModelStatusIterationLimit)       return ID2SYM(rb_intern("iteration_limit"));
    if (status == kHighsModelStatusSolutionLimit)        return ID2SYM(rb_intern("solution_limit"));
    if (status == kHighsModelStatusInterrupt)            return ID2SYM(rb_intern("interrupt"));
    return ID2SYM(rb_intern("unknown"));
}

static VALUE solver_alloc(VALUE klass) {
    HiGHSState *s = state_new();
    return Data_Wrap_Struct(klass, NULL, state_free, s);
}

/* ---- Dimension setters ---- */
static VALUE solver_set_num_col(VALUE self, VALUE v) {
    HiGHSState *s;
    Data_Get_Struct(self, HiGHSState, s);
    s->num_col = (HighsInt)NUM2LL(v);
    s->col_cost   = (double*)realloc(s->col_cost,   sizeof(double) * s->num_col);
    s->col_lower  = (double*)realloc(s->col_lower,  sizeof(double) * s->num_col);
    s->col_upper  = (double*)realloc(s->col_upper,  sizeof(double) * s->num_col);
    s->col_integrality = (HighsInt*)realloc(s->col_integrality, sizeof(HighsInt) * s->num_col);
    return v;
}

static VALUE solver_set_num_row(VALUE self, VALUE v) {
    HiGHSState *s;
    Data_Get_Struct(self, HiGHSState, s);
    s->num_row = (HighsInt)NUM2LL(v);
    s->row_lower = (double*)realloc(s->row_lower, sizeof(double) * s->num_row);
    s->row_upper = (double*)realloc(s->row_upper, sizeof(double) * s->num_row);
    return v;
}

static VALUE solver_set_num_nz(VALUE self, VALUE v) {
    HiGHSState *s;
    Data_Get_Struct(self, HiGHSState, s);
    s->num_nz = (HighsInt)NUM2LL(v);
    s->a_start  = (HighsInt*)realloc(s->a_start,  sizeof(HighsInt) * (s->num_col + 1));
    s->a_index  = (HighsInt*)realloc(s->a_index,  sizeof(HighsInt) * s->num_nz);
    s->a_value  = (double*)realloc(s->a_value,    sizeof(double) * s->num_nz);
    return v;
}

/* ---- Column data setters ---- */
static VALUE solver_set_col_cost(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_col)
        rb_raise(rb_eArgError, "col_cost length (%ld) must equal num_col (%ld)", len, (long)s->num_col);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->col_cost[i] = e == Qnil ? 0.0 : NUM2DBL(e);
    }
    return ary;
}

static VALUE solver_set_col_lower(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_col)
        rb_raise(rb_eArgError, "col_lower length (%ld) must equal num_col (%ld)", len, (long)s->num_col);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->col_lower[i] = e == Qnil ? 0.0 : NUM2DBL(e);
    }
    return ary;
}

static VALUE solver_set_col_upper(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_col)
        rb_raise(rb_eArgError, "col_upper length (%ld) must equal num_col (%ld)", len, (long)s->num_col);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->col_upper[i] = e == Qnil ? 1e30 : NUM2DBL(e);
    }
    return ary;
}

static VALUE solver_set_col_integrality(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_col)
        rb_raise(rb_eArgError, "col_integrality length (%ld) must equal num_col (%ld)", len, (long)s->num_col);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->col_integrality[i] = e == Qnil ? 0 : (HighsInt)NUM2LL(e);
    }
    return ary;
}

/* ---- Row data setters ---- */
static VALUE solver_set_row_lower(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_row)
        rb_raise(rb_eArgError, "row_lower length (%ld) must equal num_row (%ld)", len, (long)s->num_row);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->row_lower[i] = e == Qnil ? -1e30 : NUM2DBL(e);
    }
    return ary;
}

static VALUE solver_set_row_upper(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_row)
        rb_raise(rb_eArgError, "row_upper length (%ld) must equal num_row (%ld)", len, (long)s->num_row);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->row_upper[i] = e == Qnil ? 1e30 : NUM2DBL(e);
    }
    return ary;
}

/* ---- Matrix (CSC) setters ---- */
static VALUE solver_set_a_start(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)(s->num_col + 1))
        rb_raise(rb_eArgError, "a_start length (%ld) must equal num_col + 1 (%ld)", len, (long)(s->num_col + 1));
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->a_start[i] = e == Qnil ? 0 : (HighsInt)NUM2LL(e);
    }
    return ary;
}

static VALUE solver_set_a_index(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_nz)
        rb_raise(rb_eArgError, "a_index length (%ld) must equal num_nz (%ld)", len, (long)s->num_nz);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->a_index[i] = e == Qnil ? 0 : (HighsInt)NUM2LL(e);
    }
    return ary;
}

static VALUE solver_set_a_value(VALUE self, VALUE ary) {
    HiGHSState *s;
    long len = RARRAY_LEN(ary);
    Data_Get_Struct(self, HiGHSState, s);
    if (len != (long)s->num_nz)
        rb_raise(rb_eArgError, "a_value length (%ld) must equal num_nz (%ld)", len, (long)s->num_nz);
    for (long i = 0; i < len; i++) {
        VALUE e = rb_ary_entry(ary, i);
        s->a_value[i] = e == Qnil ? 0.0 : NUM2DBL(e);
    }
    return ary;
}

/* ---- Solve ---- */
static VALUE solver_solve(VALUE self) {
    HiGHSState *s;
    Data_Get_Struct(self, HiGHSState, s);

    if (s->num_col <= 0 || s->num_row <= 0)
        rb_raise(rb_eArgError, "num_col and num_row must be positive");

    /* Allocate solution buffers */
    s->col_value  = (double*)realloc(s->col_value,  sizeof(double) * s->num_col);
    s->col_dual   = (double*)realloc(s->col_dual,   sizeof(double) * s->num_col);
    s->row_value  = (double*)realloc(s->row_value,  sizeof(double) * s->num_row);
    s->row_dual   = (double*)realloc(s->row_dual,   sizeof(double) * s->num_row);
    s->col_basis  = (HighsInt*)realloc(s->col_basis, sizeof(HighsInt) * s->num_col);
    s->row_basis  = (HighsInt*)realloc(s->row_basis, sizeof(HighsInt) * s->num_row);

    /* Call HiGHS flat API */
    s->run_status = Highs_lpCall(
        s->num_col, s->num_row, s->num_nz,
        kHighsMatrixFormatColwise,
        kHighsObjSenseMinimize, 0.0,
        s->col_cost, s->col_lower, s->col_upper,
        s->row_lower, s->row_upper,
        s->a_start, s->a_index, s->a_value,
        s->col_value, s->col_dual, s->row_value, s->row_dual,
        s->col_basis, s->row_basis,
        &s->model_status
    );

    if (s->run_status != kHighsStatusOk)
        rb_raise(rb_eRuntimeError, "Highs_lpCall failed: status %ld", (long)s->run_status);

    /* Get objective value */
    void* highs = Highs_create();
    Highs_passLp(highs, s->num_col, s->num_row, s->num_nz,
                 kHighsMatrixFormatColwise, kHighsObjSenseMinimize, 0.0,
                 s->col_cost, s->col_lower, s->col_upper,
                 s->row_lower, s->row_upper,
                 s->a_start, s->a_index, s->a_value);
    Highs_run(highs);
    Highs_getDoubleInfoValue(highs, "objective_function_value", &s->objective_value);
    Highs_destroy(highs);

    /* Build result hash */
    VALUE result = rb_hash_new();
    rb_hash_aset(result, ID2SYM(rb_intern("status")), model_status_to_symbol(s->model_status));
    rb_hash_aset(result, ID2SYM(rb_intern("objective")), DBL2NUM(s->objective_value));
    rb_hash_aset(result, ID2SYM(rb_intern("num_col")), LL2NUM(s->num_col));
    rb_hash_aset(result, ID2SYM(rb_intern("num_row")), LL2NUM(s->num_row));

    VALUE cv = rb_ary_new2((long)s->num_col);
    for (HighsInt i = 0; i < s->num_col; i++) rb_ary_push(cv, DBL2NUM(s->col_value[i]));
    rb_hash_aset(result, ID2SYM(rb_intern("col_value")), cv);

    VALUE cd = rb_ary_new2((long)s->num_col);
    for (HighsInt i = 0; i < s->num_col; i++) rb_ary_push(cd, DBL2NUM(s->col_dual[i]));
    rb_hash_aset(result, ID2SYM(rb_intern("col_dual")), cd);

    VALUE rv = rb_ary_new2((long)s->num_row);
    for (HighsInt i = 0; i < s->num_row; i++) rb_ary_push(rv, DBL2NUM(s->row_value[i]));
    rb_hash_aset(result, ID2SYM(rb_intern("row_value")), rv);

    VALUE rd = rb_ary_new2((long)s->num_row);
    for (HighsInt i = 0; i < s->num_row; i++) rb_ary_push(rd, DBL2NUM(s->row_dual[i]));
    rb_hash_aset(result, ID2SYM(rb_intern("row_dual")), rd);

    return result;
}

void Init_native(void) {
    VALUE mLpSolver = rb_define_module("LpSolver");
    rb_cHiGhSSolver = rb_define_class_under(mLpSolver, "HiGhSSolver", rb_cObject);

    rb_define_alloc_func(rb_cHiGhSSolver, solver_alloc);

    /* Dimension setters */
    rb_define_method(rb_cHiGhSSolver, "num_col=", solver_set_num_col, 1);
    rb_define_method(rb_cHiGhSSolver, "num_row=", solver_set_num_row, 1);
    rb_define_method(rb_cHiGhSSolver, "num_nz=", solver_set_num_nz, 1);

    /* Column data setters */
    rb_define_method(rb_cHiGhSSolver, "col_cost=", solver_set_col_cost, 1);
    rb_define_method(rb_cHiGhSSolver, "col_lower=", solver_set_col_lower, 1);
    rb_define_method(rb_cHiGhSSolver, "col_upper=", solver_set_col_upper, 1);
    rb_define_method(rb_cHiGhSSolver, "col_integrality=", solver_set_col_integrality, 1);

    /* Row data setters */
    rb_define_method(rb_cHiGhSSolver, "row_lower=", solver_set_row_lower, 1);
    rb_define_method(rb_cHiGhSSolver, "row_upper=", solver_set_row_upper, 1);

    /* Matrix setters */
    rb_define_method(rb_cHiGhSSolver, "a_start=", solver_set_a_start, 1);
    rb_define_method(rb_cHiGhSSolver, "a_index=", solver_set_a_index, 1);
    rb_define_method(rb_cHiGhSSolver, "a_value=", solver_set_a_value, 1);

    /* Solve */
    rb_define_method(rb_cHiGhSSolver, "solve", solver_solve, 0);
}
