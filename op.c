/* $RCSfile: cmd.h,v $$Revision: 4.1 $$Date: 92/08/07 17:19:19 $
 *
 *    Copyright (c) 1991, Larry Wall
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * $Log:	cmd.h,v $
 */

#include "EXTERN.h"
#include "perl.h"

/* Lowest byte of opargs */
#define OA_MARK 1
#define OA_FOLDCONST 2
#define OA_RETSCALAR 4
#define OA_TARGET 8
#define OA_RETINTEGER 16
#define OA_OTHERINT 32
#define OA_DANGEROUS 64

/* Remaining nybbles of opargs */
#define OA_SCALAR 1
#define OA_LIST 2
#define OA_AVREF 3
#define OA_HVREF 4
#define OA_CVREF 5
#define OA_FILEREF 6
#define OA_SCALARREF 7
#define OA_OPTIONAL 8

void
cpy7bit(d,s,l)
register char *d;
register char *s;
register I32 l;
{
    while (l--)
	*d++ = *s++ & 127;
    *d = '\0';
}

OP *
no_fh_allowed(op)
OP *op;
{
    sprintf(tokenbuf,"Missing comma after first argument to %s function",
	op_name[op->op_type]);
    yyerror(tokenbuf);
    return op;
}

OP *
too_few_arguments(op)
OP *op;
{
    sprintf(tokenbuf,"Not enough arguments for %s", op_name[op->op_type]);
    yyerror(tokenbuf);
    return op;
}

OP *
too_many_arguments(op)
OP *op;
{
    sprintf(tokenbuf,"Too many arguments for %s", op_name[op->op_type]);
    yyerror(tokenbuf);
    return op;
}

/* "register" allocation */

PADOFFSET
pad_allocmy(name)
char *name;
{
    PADOFFSET off = pad_alloc(OP_PADSV, SVs_PADMY);
    SV *sv = NEWSV(0,0);
    sv_upgrade(sv, SVt_PVNV);
    sv_setpv(sv, name);
    av_store(comppadname, off, sv);
    SvNVX(sv) = (double)cop_seqmax;
    SvIVX(sv) = 99999999;
    if (*name == '@')
	av_store(comppad, off, (SV*)newAV());
    else if (*name == '%')
	av_store(comppad, off, (SV*)newHV());
    SvPADMY_on(curpad[off]);
    return off;
}

PADOFFSET
pad_findmy(name)
char *name;
{
    I32 off;
    SV *sv;
    SV **svp = AvARRAY(comppadname);
    register I32 i;
    register CONTEXT *cx;
    bool saweval;
    AV *curlist;
    AV *curname;
    CV *cv;
    I32 seq = cop_seqmax;

    for (off = comppadnamefill; off > 0; off--) {
	if ((sv = svp[off]) &&
	    seq <= SvIVX(sv) &&
	    seq > (I32)SvNVX(sv) &&
	    strEQ(SvPVX(sv), name))
	{
	    return (PADOFFSET)off;
	}
    }

    /* Nothing in current lexical context--try eval's context, if any.
     * This is necessary to let the perldb get at lexically scoped variables.
     * XXX This will also probably interact badly with eval tree caching.
     */

    saweval = FALSE;
    for (i = cxstack_ix; i >= 0; i--) {
	cx = &cxstack[i];
	switch (cx->cx_type) {
	default:
	    break;
	case CXt_EVAL:
	    saweval = TRUE;
	    break;
	case CXt_SUB:
	    if (!saweval)
		return 0;
	    cv = cx->blk_sub.cv;
	    if (debstash && CvSTASH(cv) == debstash)	/* ignore DB'* scope */
		continue;
	    seq = cxstack[i+1].blk_oldcop->cop_seq;
	    curlist = CvPADLIST(cv);
	    curname = (AV*)*av_fetch(curlist, 0, FALSE);
	    svp = AvARRAY(curname);
	    for (off = AvFILL(curname); off > 0; off--) {
		if ((sv = svp[off]) &&
		    seq <= SvIVX(sv) &&
		    seq > (I32)SvNVX(sv) &&
		    strEQ(SvPVX(sv), name))
		{
		    PADOFFSET newoff = pad_alloc(OP_PADSV, SVs_PADMY);
		    AV *oldpad = (AV*)*av_fetch(curlist, CvDEPTH(cv), FALSE);
		    SV *oldsv = *av_fetch(oldpad, off, TRUE);
		    SV *sv = NEWSV(0,0);
		    sv_upgrade(sv, SVt_PVNV);
		    sv_setpv(sv, name);
		    av_store(comppadname, newoff, sv);
		    SvNVX(sv) = (double)curcop->cop_seq;
		    SvIVX(sv) = 99999999;
		    av_store(comppad, newoff, sv_ref(oldsv));
		    return newoff;
		}
	    }
	    return 0;
	}
    }

    return 0;
}

void
pad_leavemy(fill)
I32 fill;
{
    I32 off;
    SV **svp = AvARRAY(comppadname);
    SV *sv;
    for (off = AvFILL(comppadname); off > fill; off--) {
	if (sv = svp[off])
	    SvIVX(sv) = cop_seqmax;
    }
}

PADOFFSET
pad_alloc(optype,tmptype)	
I32 optype;
U32 tmptype;
{
    SV *sv;
    I32 retval;

    if (AvARRAY(comppad) != curpad)
	croak("panic: pad_alloc");
    if (tmptype & SVs_PADMY) {
	do {
	    sv = *av_fetch(comppad, AvFILL(comppad) + 1, TRUE);
	} while (SvPADBUSY(sv));		/* need a fresh one */
	retval = AvFILL(comppad);
    }
    else {
	do {
	    sv = *av_fetch(comppad, ++padix, TRUE);
	} while (SvSTORAGE(sv) & (SVs_PADTMP|SVs_PADMY));
	retval = padix;
    }
    SvSTORAGE(sv) |= tmptype;
    curpad = AvARRAY(comppad);
    DEBUG_X(fprintf(stderr, "Pad alloc %d for %s\n", retval, op_name[optype]));
    return (PADOFFSET)retval;
}

SV *
pad_sv(po)
PADOFFSET po;
{
    if (!po)
	croak("panic: pad_sv po");
    DEBUG_X(fprintf(stderr, "Pad sv %d\n", po));
    return curpad[po];		/* eventually we'll turn this into a macro */
}

void
pad_free(po)
PADOFFSET po;
{
    if (AvARRAY(comppad) != curpad)
	croak("panic: pad_free curpad");
    if (!po)
	croak("panic: pad_free po");
    DEBUG_X(fprintf(stderr, "Pad free %d\n", po));
    if (curpad[po])
	SvPADTMP_off(curpad[po]);
    if (po < padix)
	padix = po - 1;
}

void
pad_swipe(po)
PADOFFSET po;
{
    if (AvARRAY(comppad) != curpad)
	croak("panic: pad_swipe curpad");
    if (!po)
	croak("panic: pad_swipe po");
    DEBUG_X(fprintf(stderr, "Pad swipe %d\n", po));
    curpad[po] = NEWSV(0,0);
    SvPADTMP_off(curpad[po]);
    if (po < padix)
	padix = po - 1;
}

void
pad_reset()
{
    register I32 po;

    if (AvARRAY(comppad) != curpad)
	croak("panic: pad_reset curpad");
    DEBUG_X(fprintf(stderr, "Pad reset\n"));
    for (po = AvMAX(comppad); po > 0; po--) {
	if (curpad[po])
	    SvPADTMP_off(curpad[po]);
    }
    padix = 0;
}

/* Destructor */

void
op_free(op)
OP *op;
{
    register OP *kid;

    if (!op)
	return;

    if (op->op_flags & OPf_KIDS) {
	for (kid = cUNOP->op_first; kid; kid = kid->op_sibling)
	    op_free(kid);
    }

    if (op->op_targ > 0)
	pad_free(op->op_targ);

    switch (op->op_type) {
    case OP_GVSV:
    case OP_GV:
	sv_free((SV*)cGVOP->op_gv);
	break;
    case OP_CONST:
	sv_free(cSVOP->op_sv);
	break;
    }

    Safefree(op);
}

/* Contextualizers */

#define LINKLIST(o) ((o)->op_next ? (o)->op_next : linklist((OP*)o))

OP *
linklist(op)
OP *op;
{
    register OP *kid;

    if (op->op_next)
	return op->op_next;

    /* establish postfix order */
    if (cUNOP->op_first) {
	op->op_next = LINKLIST(cUNOP->op_first);
	for (kid = cUNOP->op_first; kid; kid = kid->op_sibling) {
	    if (kid->op_sibling)
		kid->op_next = LINKLIST(kid->op_sibling);
	    else
		kid->op_next = op;
	}
    }
    else
	op->op_next = op;

    return op->op_next;
}

OP *
scalarkids(op)
OP *op;
{
    OP *kid;
    if (op && op->op_flags & OPf_KIDS) {
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    scalar(kid);
    }
    return op;
}

OP *
scalar(op)
OP *op;
{
    OP *kid;

    if (!op || (op->op_flags & OPf_KNOW)) /* assumes no premature commitment */
	return op;

    op->op_flags &= ~OPf_LIST;
    op->op_flags |= OPf_KNOW;

    switch (op->op_type) {
    case OP_REPEAT:
	scalar(cBINOP->op_first);
	return op;
    case OP_OR:
    case OP_AND:
    case OP_COND_EXPR:
	break;
    default:
    case OP_MATCH:
    case OP_SUBST:
    case OP_NULL:
	if (!(op->op_flags & OPf_KIDS))
	    return op;
	break;
    case OP_SCOPE:
    case OP_LEAVE:
    case OP_LEAVETRY:
    case OP_LINESEQ:
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		scalar(kid);
	}
	curcop = &compiling;
	return op;
    case OP_LIST:
	op = prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), op);
	break;
    }
    for (kid = cUNOP->op_first->op_sibling; kid; kid = kid->op_sibling)
	scalar(kid);
    return op;
}

OP *
scalarvoid(op)
OP *op;
{
    OP *kid;

    if (!op)
	return op;
    if (op->op_flags & OPf_LIST)
	return op;

    op->op_flags |= OPf_KNOW;

    switch (op->op_type) {
    default:
	if (dowarn && (opargs[op->op_type] & OA_FOLDCONST) &&
		!(op->op_flags & OPf_STACKED))
	    warn("Useless use of %s", op_name[op->op_type]);
	return op;

    case OP_NEXTSTATE:
	curcop = ((COP*)op);		/* for warning above */
	break;

    case OP_CONST:
	op->op_type = OP_NULL;		/* don't execute a constant */
	sv_free(cSVOP->op_sv);		/* don't even remember it */
	break;

    case OP_POSTINC:
	op->op_type = OP_PREINC;
	op->op_ppaddr = ppaddr[OP_PREINC];
	break;

    case OP_POSTDEC:
	op->op_type = OP_PREDEC;
	op->op_ppaddr = ppaddr[OP_PREDEC];
	break;

    case OP_REPEAT:
	scalarvoid(cBINOP->op_first);
	break;
    case OP_OR:
    case OP_AND:
    case OP_COND_EXPR:
	for (kid = cUNOP->op_first->op_sibling; kid; kid = kid->op_sibling)
	    scalarvoid(kid);
	break;
    case OP_ENTERTRY:
    case OP_ENTER:
    case OP_SCALAR:
    case OP_NULL:
	if (!(op->op_flags & OPf_KIDS))
	    break;
    case OP_SCOPE:
    case OP_LEAVE:
    case OP_LEAVETRY:
    case OP_LINESEQ:
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    scalarvoid(kid);
	break;
    case OP_LIST:
	op = prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), op);
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    scalarvoid(kid);
	break;
    }
    return op;
}

OP *
listkids(op)
OP *op;
{
    OP *kid;
    if (op && op->op_flags & OPf_KIDS) {
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    list(kid);
    }
    return op;
}

OP *
list(op)
OP *op;
{
    OP *kid;

    if (!op || (op->op_flags & OPf_KNOW)) /* assumes no premature commitment */
	return op;

    op->op_flags |= (OPf_KNOW | OPf_LIST);

    switch (op->op_type) {
    case OP_FLOP:
    case OP_REPEAT:
	list(cBINOP->op_first);
	break;
    case OP_OR:
    case OP_AND:
    case OP_COND_EXPR:
	for (kid = cUNOP->op_first->op_sibling; kid; kid = kid->op_sibling)
	    list(kid);
	break;
    default:
    case OP_MATCH:
    case OP_SUBST:
    case OP_NULL:
	if (!(op->op_flags & OPf_KIDS))
	    break;
	if (!op->op_next && cUNOP->op_first->op_type == OP_FLOP) {
	    list(cBINOP->op_first);
	    return gen_constant_list(op);
	}
    case OP_LIST:
	listkids(op);
	break;
    case OP_SCOPE:
    case OP_LEAVE:
    case OP_LEAVETRY:
    case OP_LINESEQ:
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		list(kid);
	}
	curcop = &compiling;
	break;
    }
    return op;
}

static OP *
guess_mark(op)
OP *op;
{
    if (op->op_type == OP_LIST &&
	     (!cLISTOP->op_first ||
	      cLISTOP->op_first->op_type != OP_PUSHMARK))
    {
	op = prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), op);
	op->op_private |= OPpLIST_GUESSED;
    }
    return op;
}

OP *
scalarseq(op)
OP *op;
{
    OP *kid;
    OP **prev;

    if (op) {
	if (op->op_type == OP_LINESEQ ||
	     op->op_type == OP_SCOPE ||
	     op->op_type == OP_LEAVE ||
	     op->op_type == OP_LEAVETRY)
	{
	    prev = &cLISTOP->op_first;
	    for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling) {
		if (kid->op_sibling) {
		    scalarvoid(kid);
		    prev = &kid->op_sibling;
		}
		else
		    *prev = guess_mark(kid);
	    }
	    curcop = &compiling;
	}
	op->op_flags &= ~OPf_PARENS;
	if (needblockscope)
	    op->op_flags |= OPf_PARENS;
    }
    return op;
}

OP *
modkids(op, type)
OP *op;
I32 type;
{
    OP *kid;
    if (op && op->op_flags & OPf_KIDS) {
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    mod(kid, type);
    }
    return op;
}

static I32 modcount;

OP *
mod(op, type)
OP *op;
I32 type;
{
    OP *kid;
    SV *sv;

    if (!op)
	return op;

    switch (op->op_type) {
    case OP_ENTERSUBR:
	if ((type == OP_DEFINED || type == OP_UNDEF || type == OP_REFGEN) &&
	  !(op->op_flags & OPf_STACKED)) {
	    op->op_type = OP_RV2CV;		/* entersubr => rv2cv */
	    op->op_ppaddr = ppaddr[OP_RV2CV];
	    cUNOP->op_first->op_type = OP_NULL;	/* disable pushmark */
	    cUNOP->op_first->op_ppaddr = ppaddr[OP_NULL];
	    break;
	}
	/* FALL THROUGH */
    default:
	if (type == OP_DEFINED)
	    return scalar(op);		/* ordinary expression, not lvalue */
	sprintf(tokenbuf, "Can't %s %s in %s",
	    type == OP_REFGEN ? "refer to" : "modify", 
	    op_name[op->op_type],
	    type ? op_name[type] : "local");
	yyerror(tokenbuf);
	return op;

    case OP_COND_EXPR:
	for (kid = cUNOP->op_first->op_sibling; kid; kid = kid->op_sibling)
	    mod(kid, type);
	break;

    case OP_RV2AV:
    case OP_RV2HV:
    case OP_RV2GV:
	ref(cUNOP->op_first, op->op_type);
	/* FALL THROUGH */
    case OP_AASSIGN:
    case OP_ASLICE:
    case OP_HSLICE:
    case OP_NEXTSTATE:
    case OP_DBSTATE:
	modcount = 10000;
	break;
    case OP_RV2SV:
	if (type == OP_RV2AV || type == OP_RV2HV)
	    op->op_private = type;
	/* FALL THROUGH */
    case OP_PADSV:
    case OP_PADAV:
    case OP_PADHV:
    case OP_UNDEF:
    case OP_GV:
    case OP_AV2ARYLEN:
    case OP_SASSIGN:
    case OP_REFGEN:
    case OP_ANONLIST:
    case OP_ANONHASH:
	modcount++;
	break;

    case OP_PUSHMARK:
	break;

    case OP_SUBSTR:
    case OP_VEC:
	op->op_targ = pad_alloc(op->op_type, SVs_PADMY);
	sv = PAD_SV(op->op_targ);
	sv_upgrade(sv, SVt_PVLV);
	sv_magic(sv, 0, op->op_type == OP_VEC ? 'v' : 'x', 0, 0);
	curpad[op->op_targ] = sv;
	/* FALL THROUGH */
    case OP_NULL:
	if (!(op->op_flags & OPf_KIDS))
	    croak("panic: mod");
	mod(cBINOP->op_first, type ? type : op->op_type);
	break;
    case OP_AELEM:
    case OP_HELEM:
	mod(cBINOP->op_first, type ? type : op->op_type);
	if (type == OP_RV2AV || type == OP_RV2HV)
	    op->op_private = type;
	break;

    case OP_SCOPE:
    case OP_LEAVE:
    case OP_ENTER:
	if (type != OP_RV2HV && type != OP_RV2AV)
	    break;
	if (!(op->op_flags & OPf_KIDS))
	    break;
	/* FALL THROUGH */
    case OP_LIST:
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    mod(kid, type);
	break;
    }
    op->op_flags |= OPf_LVAL;
    if (!type) {
	op->op_flags &= ~OPf_SPECIAL;
	op->op_flags |= OPf_INTRO;
    }
    else if (type == OP_AASSIGN || type == OP_SASSIGN)
	op->op_flags |= OPf_SPECIAL;
    return op;
}

OP *
refkids(op, type)
OP *op;
I32 type;
{
    OP *kid;
    if (op && op->op_flags & OPf_KIDS) {
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    ref(kid, type);
    }
    return op;
}

OP *
ref(op, type)
OP *op;
I32 type;
{
    OP *kid;
    SV *sv;

    if (!op)
	return op;

    switch (op->op_type) {
    default:
	sprintf(tokenbuf, "Can't use %s as reference in %s",
	    op_name[op->op_type],
	    type ? op_name[type] : "local");
	yyerror(tokenbuf);
	return op;

    case OP_COND_EXPR:
	for (kid = cUNOP->op_first->op_sibling; kid; kid = kid->op_sibling)
	    ref(kid, type);
	break;

    case OP_RV2AV:
    case OP_RV2HV:
    case OP_RV2GV:
	ref(cUNOP->op_first, op->op_type);
	/* FALL THROUGH */
    case OP_AASSIGN:
    case OP_ASLICE:
    case OP_HSLICE:
    case OP_NEXTSTATE:
    case OP_DBSTATE:
    case OP_ENTERSUBR:
	break;
    case OP_RV2SV:
	if (type == OP_RV2AV || type == OP_RV2HV)
	    op->op_private = type;
	/* FALL THROUGH */
    case OP_PADSV:
    case OP_PADAV:
    case OP_PADHV:
    case OP_UNDEF:
    case OP_GV:
    case OP_AV2ARYLEN:
    case OP_SASSIGN:
    case OP_REFGEN:
    case OP_ANONLIST:
    case OP_ANONHASH:
	break;

    case OP_PUSHMARK:
	break;

    case OP_SUBSTR:
    case OP_VEC:
	op->op_targ = pad_alloc(op->op_type, SVs_PADMY);
	sv = PAD_SV(op->op_targ);
	sv_upgrade(sv, SVt_PVLV);
	sv_magic(sv, 0, op->op_type == OP_VEC ? 'v' : 'x', 0, 0);
	curpad[op->op_targ] = sv;
	/* FALL THROUGH */
    case OP_NULL:
	if (!(op->op_flags & OPf_KIDS))
	    break;
	ref(cBINOP->op_first, type ? type : op->op_type);
	break;
    case OP_AELEM:
    case OP_HELEM:
	ref(cBINOP->op_first, type ? type : op->op_type);
	if (type == OP_RV2AV || type == OP_RV2HV)
	    op->op_private = type;
	break;

    case OP_SCOPE:
    case OP_LEAVE:
    case OP_ENTER:
	if (type != OP_RV2HV && type != OP_RV2AV)
	    break;
	if (!(op->op_flags & OPf_KIDS))
	    break;
	/* FALL THROUGH */
    case OP_LIST:
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    ref(kid, type);
	break;
    }
    op->op_flags |= OPf_LVAL;
    if (!type) {
	op->op_flags &= ~OPf_SPECIAL;
	op->op_flags |= OPf_INTRO;
    }
    else if (type == OP_AASSIGN || type == OP_SASSIGN)
	op->op_flags |= OPf_SPECIAL;
    return op;
}

OP *
my(op)
OP *op;
{
    OP *kid;
    SV *sv;
    I32 type;

    if (!op)
	return op;

    type = op->op_type;
    if (type == OP_LIST) {
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    my(kid);
    }
    else if (type != OP_PADSV &&
	     type != OP_PADAV &&
	     type != OP_PADHV &&
	     type != OP_PUSHMARK)
    {
	sprintf(tokenbuf, "Can't declare %s in my", op_name[op->op_type]);
	yyerror(tokenbuf);
	return op;
    }
    op->op_flags |= OPf_LVAL|OPf_INTRO;
    return op;
}

OP *
sawparens(o)
OP *o;
{
    if (o)
	o->op_flags |= OPf_PARENS;
    return o;
}

OP *
bind_match(type, left, right)
I32 type;
OP *left;
OP *right;
{
    OP *op;

    if (right->op_type == OP_MATCH ||
	right->op_type == OP_SUBST ||
	right->op_type == OP_TRANS) {
	right->op_flags |= OPf_STACKED;
	if (right->op_type != OP_MATCH)
	    left = mod(left, right->op_type);
	if (right->op_type == OP_TRANS)
	    op = newBINOP(OP_NULL, 0, scalar(left), right);
	else
	    op = prepend_elem(right->op_type, scalar(left), right);
	if (type == OP_NOT)
	    return newUNOP(OP_NOT, 0, scalar(op));
	return op;
    }
    else
	return bind_match(type, left,
		pmruntime(newPMOP(OP_MATCH, 0), right, Nullop));
}

OP *
invert(op)
OP *op;
{
    if (!op)
	return op;
    /* XXX need to optimize away NOT NOT here?  Or do we let optimizer do it? */
    return newUNOP(OP_NOT, OPf_SPECIAL, scalar(op));
}

OP *
scope(o)
OP *o;
{
    if (o) {
	if (o->op_flags & OPf_PARENS) {
	    o = prepend_elem(OP_LINESEQ, newOP(OP_ENTER, 0), o);
	    o->op_type = OP_LEAVE;
	    o->op_ppaddr = ppaddr[OP_LEAVE];
	}
	else {
	    if (o->op_type == OP_LINESEQ) {
		OP *kid;
		o->op_type = OP_SCOPE;
		o->op_ppaddr = ppaddr[OP_SCOPE];
		kid = ((LISTOP*)o)->op_first;
		if (kid->op_type == OP_NEXTSTATE) {
		    kid->op_type = OP_NULL;
		    kid->op_ppaddr = ppaddr[OP_NULL];
		}
	    }
	    else
		o = newUNOP(OP_SCOPE, 0, o);
	}
    }
    return o;
}

OP *
block_head(o, startp)
OP *o;
OP **startp;
{
    if (!o) {
	*startp = 0;
	return o;
    }
    o = scope(scalarseq(o));
    *startp = LINKLIST(o);
    o->op_next = 0;
    peep(*startp);
    return o;
}

OP *
localize(o, lex)
OP *o;
I32 lex;
{
    if (o->op_flags & OPf_PARENS)
	list(o);
    else
	scalar(o);
    in_my = FALSE;
    if (lex)
	return my(o);
    else
	return mod(o, OP_NULL);		/* a bit kludgey */
}

OP *
jmaybe(o)
OP *o;
{
    if (o->op_type == OP_LIST) {
	o = convert(OP_JOIN, 0,
		prepend_elem(OP_LIST,
		    newSVREF(newGVOP(OP_GV, 0, gv_fetchpv(";", TRUE))),
		    o));
    }
    return o;
}

OP *
fold_constants(o)
register OP *o;
{
    register OP *curop;
    I32 type = o->op_type;
    SV *sv;

    if (opargs[type] & OA_RETSCALAR)
	scalar(o);
    if (opargs[type] & OA_TARGET)
	o->op_targ = pad_alloc(type, SVs_PADTMP);

    if (!(opargs[type] & OA_FOLDCONST))
	goto nope;

    for (curop = LINKLIST(o); curop != o; curop = LINKLIST(curop)) {
	if (curop->op_type != OP_CONST &&
		curop->op_type != OP_LIST &&
		curop->op_type != OP_SCALAR &&
		curop->op_type != OP_PUSHMARK) {
	    goto nope;
	}
    }

    curop = LINKLIST(o);
    o->op_next = 0;
    op = curop;
    run();
    if (o->op_targ && *stack_sp == PAD_SV(o->op_targ))
	pad_swipe(o->op_targ);
    op_free(o);
    if (type == OP_RV2GV)
	return newGVOP(OP_GV, 0, *(stack_sp--));
    else
	return newSVOP(OP_CONST, 0, *(stack_sp--));
    
  nope:
    if (!(opargs[type] & OA_OTHERINT))
	return o;
    if (!(o->op_flags & OPf_KIDS))
	return o;

    for (curop = ((UNOP*)o)->op_first; curop; curop = curop->op_sibling) {
	if (curop->op_type == OP_CONST) {
	    if (SvIOK(((SVOP*)curop)->op_sv))
		continue;
	    return o;
	}
	if (opargs[curop->op_type] & OA_RETINTEGER)
	    continue;
	return o;
    }

    o->op_ppaddr = ppaddr[++(o->op_type)];
    return o;
}

OP *
gen_constant_list(o)
register OP *o;
{
    register OP *curop;
    OP *anonop;
    I32 tmpmark;
    I32 tmpsp;
    I32 oldtmps_floor = tmps_floor;
    AV *av;
    GV *gv;

    tmpmark = stack_sp - stack_base;
    anonop = newANONLIST(o);
    curop = LINKLIST(anonop);
    anonop->op_next = 0;
    op = curop;
    run();
    tmpsp = stack_sp - stack_base;
    tmps_floor = oldtmps_floor;
    stack_sp = stack_base + tmpmark;

    o->op_type = OP_RV2AV;
    o->op_ppaddr = ppaddr[OP_RV2AV];
    o->op_sibling = 0;
    curop = ((UNOP*)o)->op_first;
    ((UNOP*)o)->op_first = newSVOP(OP_CONST, 0, newSVsv(stack_sp[1]));
    op_free(curop);
    curop = ((UNOP*)anonop)->op_first;
    curop = ((UNOP*)curop)->op_first;
    curop->op_sibling = 0;
    op_free(anonop);
    o->op_next = 0;
    linklist(o);
    return list(o);
}

OP *
convert(type, flags, op)
I32 type;
I32 flags;
OP* op;
{
    OP *kid;
    OP *last;

    if (opargs[type] & OA_MARK)
	op = prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), op);

    if (!op || op->op_type != OP_LIST)
	op = newLISTOP(OP_LIST, 0, op, Nullop);

    op->op_type = type;
    op->op_ppaddr = ppaddr[type];
    op->op_flags |= flags;

    op = (*check[type])(op);
    if (op->op_type != type)
	return op;

    if (cLISTOP->op_children < 7) {
	/* XXX do we really need to do this if we're done appending?? */
	for (kid = cLISTOP->op_first; kid; kid = kid->op_sibling)
	    last = kid;
	cLISTOP->op_last = last;	/* in case check substituted last arg */
    }

    return fold_constants(op);
}

/* List constructors */

OP *
append_elem(type, first, last)
I32 type;
OP* first;
OP* last;
{
    if (!first)
	return last;
    else if (!last)
	return first;
    else if (first->op_type == type) {
	if (first->op_flags & OPf_KIDS)
	    ((LISTOP*)first)->op_last->op_sibling = last;
	else {
	    first->op_flags |= OPf_KIDS;
	    ((LISTOP*)first)->op_first = last;
	}
	((LISTOP*)first)->op_last = last;
	((LISTOP*)first)->op_children++;
	return first;
    }

    return newLISTOP(type, 0, first, last);
}

OP *
append_list(type, first, last)
I32 type;
LISTOP* first;
LISTOP* last;
{
    if (!first)
	return (OP*)last;
    else if (!last)
	return (OP*)first;
    else if (first->op_type != type)
	return prepend_elem(type, (OP*)first, (OP*)last);
    else if (last->op_type != type)
	return append_elem(type, (OP*)first, (OP*)last);

    first->op_last->op_sibling = last->op_first;
    first->op_last = last->op_last;
    first->op_children += last->op_children;
    if (first->op_children)
	last->op_flags |= OPf_KIDS;

    Safefree(last);
    return (OP*)first;
}

OP *
prepend_elem(type, first, last)
I32 type;
OP* first;
OP* last;
{
    if (!first)
	return last;
    else if (!last)
	return first;
    else if (last->op_type == type) {
	if (!(last->op_flags & OPf_KIDS)) {
	    ((LISTOP*)last)->op_last = first;
	    last->op_flags |= OPf_KIDS;
	}
	first->op_sibling = ((LISTOP*)last)->op_first;
	((LISTOP*)last)->op_first = first;
	((LISTOP*)last)->op_children++;
	return last;
    }

    return newLISTOP(type, 0, first, last);
}

/* Constructors */

OP *
newNULLLIST()
{
    return Nullop;
}

OP *
newLISTOP(type, flags, first, last)
I32 type;
I32 flags;
OP* first;
OP* last;
{
    LISTOP *listop;

    Newz(1101, listop, 1, LISTOP);

    listop->op_type = type;
    listop->op_ppaddr = ppaddr[type];
    listop->op_children = (first != 0) + (last != 0);
    listop->op_flags = flags;
    if (listop->op_children)
	listop->op_flags |= OPf_KIDS;

    if (!last && first)
	last = first;
    else if (!first && last)
	first = last;
    listop->op_first = first;
    listop->op_last = last;
    if (first && first != last)
	first->op_sibling = last;

    return (OP*)listop;
}

OP *
newOP(type, flags)
I32 type;
I32 flags;
{
    OP *op;
    Newz(1101, op, 1, OP);
    op->op_type = type;
    op->op_ppaddr = ppaddr[type];
    op->op_flags = flags;

    op->op_next = op;
    /* op->op_private = 0; */
    if (opargs[type] & OA_RETSCALAR)
	scalar(op);
    if (opargs[type] & OA_TARGET)
	op->op_targ = pad_alloc(type, SVs_PADTMP);
    return (*check[type])(op);
}

OP *
newUNOP(type, flags, first)
I32 type;
I32 flags;
OP* first;
{
    UNOP *unop;

    if (opargs[type] & OA_MARK) {
	if (first->op_type == OP_LIST)
	    prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), first);
	else
	    return newBINOP(type, flags, newOP(OP_PUSHMARK, 0), first);
    }

    if (!first)
	first = newOP(OP_STUB, 0); 

    Newz(1101, unop, 1, UNOP);
    unop->op_type = type;
    unop->op_ppaddr = ppaddr[type];
    unop->op_first = first;
    unop->op_flags = flags | OPf_KIDS;
    unop->op_private = 1;

    unop = (UNOP*)(*check[type])((OP*)unop);
    if (unop->op_next)
	return (OP*)unop;

    return fold_constants(unop);
}

OP *
newBINOP(type, flags, first, last)
I32 type;
I32 flags;
OP* first;
OP* last;
{
    BINOP *binop;
    Newz(1101, binop, 1, BINOP);

    if (!first)
	first = newOP(OP_NULL, 0);

    binop->op_type = type;
    binop->op_ppaddr = ppaddr[type];
    binop->op_first = first;
    binop->op_flags = flags | OPf_KIDS;
    if (!last) {
	last = first;
	binop->op_private = 1;
    }
    else {
	binop->op_private = 2;
	first->op_sibling = last;
    }

    binop = (BINOP*)(*check[type])((OP*)binop);
    if (binop->op_next)
	return (OP*)binop;

    binop->op_last = last = binop->op_first->op_sibling;

    return fold_constants(binop);
}

OP *
pmtrans(op, expr, repl)
OP *op;
OP *expr;
OP *repl;
{
    PMOP *pm = (PMOP*)op;
    SV *tstr = ((SVOP*)expr)->op_sv;
    SV *rstr = ((SVOP*)repl)->op_sv;
    STRLEN tlen;
    STRLEN rlen;
    register char *t = SvPV(tstr, tlen);
    register char *r = SvPV(rstr, rlen);
    register I32 i;
    register I32 j;
    I32 squash;
    I32 delete;
    I32 complement;
    register short *tbl;

    tbl = (short*)cPVOP->op_pv;
    complement	= op->op_private & OPpTRANS_COMPLEMENT;
    delete	= op->op_private & OPpTRANS_DELETE;
    squash	= op->op_private & OPpTRANS_SQUASH;

    if (complement) {
	Zero(tbl, 256, short);
	for (i = 0; i < tlen; i++)
	    tbl[t[i] & 0377] = -1;
	for (i = 0, j = 0; i < 256; i++) {
	    if (!tbl[i]) {
		if (j >= rlen) {
		    if (delete)
			tbl[i] = -2;
		    else if (rlen)
			tbl[i] = r[j-1] & 0377;
		    else
			tbl[i] = i;
		}
		else
		    tbl[i] = r[j++] & 0377;
	    }
	}
    }
    else {
	if (!rlen && !delete) {
	    r = t; rlen = tlen;
	}
	for (i = 0; i < 256; i++)
	    tbl[i] = -1;
	for (i = 0, j = 0; i < tlen; i++,j++) {
	    if (j >= rlen) {
		if (delete) {
		    if (tbl[t[i] & 0377] == -1)
			tbl[t[i] & 0377] = -2;
		    continue;
		}
		--j;
	    }
	    if (tbl[t[i] & 0377] == -1)
		tbl[t[i] & 0377] = r[j] & 0377;
	}
    }
    op_free(expr);
    op_free(repl);

    return op;
}

OP *
newPMOP(type, flags)
I32 type;
I32 flags;
{
    PMOP *pmop;

    Newz(1101, pmop, 1, PMOP);
    pmop->op_type = type;
    pmop->op_ppaddr = ppaddr[type];
    pmop->op_flags = flags;
    pmop->op_private = 0;

    /* link into pm list */
    if (type != OP_TRANS) {
	pmop->op_pmnext = HvPMROOT(curstash);
	HvPMROOT(curstash) = pmop;
    }

    return (OP*)pmop;
}

OP *
pmruntime(op, expr, repl)
OP *op;
OP *expr;
OP *repl;
{
    PMOP *pm;
    LOGOP *rcop;

    if (op->op_type == OP_TRANS)
	return pmtrans(op, expr, repl);

    pm = (PMOP*)op;

    if (expr->op_type == OP_CONST) {
	STRLEN plen;
	SV *pat = ((SVOP*)expr)->op_sv;
	char *p = SvPV(pat, plen);
	if ((op->op_flags & OPf_SPECIAL) && strEQ(p, " ")) {
	    sv_setpvn(pat, "\\s+", 3);
	    p = SvPV(pat, plen);
	    pm->op_pmflags |= PMf_SKIPWHITE;
	}
	scan_prefix(pm, p, plen);
	if (pm->op_pmshort && (pm->op_pmflags & PMf_SCANFIRST))
	    fbm_compile(pm->op_pmshort, pm->op_pmflags & PMf_FOLD);
	pm->op_pmregexp = regcomp(p, p + plen, pm->op_pmflags & PMf_FOLD);
	hoistmust(pm);
	op_free(expr);
    }
    else {
	if (pm->op_pmflags & PMf_KEEP)
	    expr = newUNOP(OP_REGCMAYBE,0,expr);

	Newz(1101, rcop, 1, LOGOP);
	rcop->op_type = OP_REGCOMP;
	rcop->op_ppaddr = ppaddr[OP_REGCOMP];
	rcop->op_first = scalar(expr);
	rcop->op_flags |= OPf_KIDS;
	rcop->op_private = 1;
	rcop->op_other = op;

	/* establish postfix order */
	if (pm->op_pmflags & PMf_KEEP) {
	    LINKLIST(expr);
	    rcop->op_next = expr;
	    ((UNOP*)expr)->op_first->op_next = (OP*)rcop;
	}
	else {
	    rcop->op_next = LINKLIST(expr);
	    expr->op_next = (OP*)rcop;
	}

	prepend_elem(op->op_type, scalar((OP*)rcop), op);
    }

    if (repl) {
	if (repl->op_type == OP_CONST) {
	    pm->op_pmflags |= PMf_CONST;
	    prepend_elem(op->op_type, scalar(repl), op);
	}
	else {
	    OP *curop;
	    OP *lastop = 0;
	    for (curop = LINKLIST(repl); curop!=repl; curop = LINKLIST(curop)) {
		if (opargs[curop->op_type] & OA_DANGEROUS) {
		    if (curop->op_type == OP_GV) {
			GV *gv = ((GVOP*)curop)->op_gv;
			if (strchr("&`'123456789+", *GvENAME(gv)))
			    break;
		    }
		    else if (curop->op_type == OP_RV2CV)
			break;
		    else if (curop->op_type == OP_RV2SV ||
			     curop->op_type == OP_RV2AV ||
			     curop->op_type == OP_RV2HV ||
			     curop->op_type == OP_RV2GV) {
			if (lastop && lastop->op_type != OP_GV)	/*funny deref?*/
			    break;
		    }
		    else
			break;
		}
		lastop = curop;
	    }
	    if (curop == repl) {
		pm->op_pmflags |= PMf_CONST;	/* const for long enough */
		prepend_elem(op->op_type, scalar(repl), op);
	    }
	    else {
		Newz(1101, rcop, 1, LOGOP);
		rcop->op_type = OP_SUBSTCONT;
		rcop->op_ppaddr = ppaddr[OP_SUBSTCONT];
		rcop->op_first = scalar(repl);
		rcop->op_flags |= OPf_KIDS;
		rcop->op_private = 1;
		rcop->op_other = op;

		/* establish postfix order */
		rcop->op_next = LINKLIST(repl);
		repl->op_next = (OP*)rcop;

		pm->op_pmreplroot = scalar((OP*)rcop);
		pm->op_pmreplstart = LINKLIST(rcop);
		rcop->op_next = 0;
	    }
	}
    }

    return (OP*)pm;
}

OP *
newSVOP(type, flags, sv)
I32 type;
I32 flags;
SV *sv;
{
    SVOP *svop;
    Newz(1101, svop, 1, SVOP);
    svop->op_type = type;
    svop->op_ppaddr = ppaddr[type];
    svop->op_sv = sv;
    svop->op_next = (OP*)svop;
    svop->op_flags = flags;
    if (opargs[type] & OA_RETSCALAR)
	scalar((OP*)svop);
    if (opargs[type] & OA_TARGET)
	svop->op_targ = pad_alloc(type, SVs_PADTMP);
    return (*check[type])((OP*)svop);
}

OP *
newGVOP(type, flags, gv)
I32 type;
I32 flags;
GV *gv;
{
    GVOP *gvop;
    Newz(1101, gvop, 1, GVOP);
    gvop->op_type = type;
    gvop->op_ppaddr = ppaddr[type];
    gvop->op_gv = (GV*)sv_ref(gv);
    gvop->op_next = (OP*)gvop;
    gvop->op_flags = flags;
    if (opargs[type] & OA_RETSCALAR)
	scalar((OP*)gvop);
    if (opargs[type] & OA_TARGET)
	gvop->op_targ = pad_alloc(type, SVs_PADTMP);
    return (*check[type])((OP*)gvop);
}

OP *
newPVOP(type, flags, pv)
I32 type;
I32 flags;
char *pv;
{
    PVOP *pvop;
    Newz(1101, pvop, 1, PVOP);
    pvop->op_type = type;
    pvop->op_ppaddr = ppaddr[type];
    pvop->op_pv = pv;
    pvop->op_next = (OP*)pvop;
    pvop->op_flags = flags;
    if (opargs[type] & OA_RETSCALAR)
	scalar((OP*)pvop);
    if (opargs[type] & OA_TARGET)
	pvop->op_targ = pad_alloc(type, SVs_PADTMP);
    return (*check[type])((OP*)pvop);
}

OP *
newCVOP(type, flags, cv, cont)
I32 type;
I32 flags;
CV *cv;
OP *cont;
{
    CVOP *cvop;
    Newz(1101, cvop, 1, CVOP);
    cvop->op_type = type;
    cvop->op_ppaddr = ppaddr[type];
    cvop->op_cv = cv;
    cvop->op_cont = cont;
    cvop->op_next = (OP*)cvop;
    cvop->op_flags = flags;
    if (opargs[type] & OA_RETSCALAR)
	scalar((OP*)cvop);
    if (opargs[type] & OA_TARGET)
	cvop->op_targ = pad_alloc(type, SVs_PADTMP);
    return (*check[type])((OP*)cvop);
}

void
package(op)
OP *op;
{
    SV *sv;

    save_hptr(&curstash);
    save_item(curstname);
    if (op) {
	STRLEN len;
	char *name;
	sv = cSVOP->op_sv;
	curstash = fetch_stash(sv,TRUE);
	name = SvPV(sv, len);
	sv_setpvn(curstname, name, len);
	op_free(op);
    }
    else {
	sv_setpv(curstname,"<none>");
	curstash = Nullhv;
    }
    copline = NOLINE;
    expect = XBLOCK;
}

HV*
fetch_stash(sv,create)
SV *sv;
I32 create;
{
    char tmpbuf[256];
    HV *stash;
    GV *tmpgv;
    char *name = SvPV(sv, na);
    sprintf(tmpbuf,"%s::",name);
    tmpgv = gv_fetchpv(tmpbuf,create);
    if (!tmpgv)
	return 0;
    if (!GvHV(tmpgv))
	GvHV(tmpgv) = newHV();
    stash = GvHV(tmpgv);
    if (!HvNAME(stash))
	HvNAME(stash) = savestr(name);
    return stash;
}

OP *
newSLICEOP(flags, subscript, listval)
I32 flags;
OP *subscript;
OP *listval;
{
    return newBINOP(OP_LSLICE, flags,
	    list(prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), subscript)),
	    list(prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), listval)) );
}

static I32
list_assignment(op)
register OP *op;
{
    if (!op)
	return TRUE;

    if (op->op_type == OP_NULL && op->op_flags & OPf_KIDS)
	op = cUNOP->op_first;

    if (op->op_type == OP_COND_EXPR) {
	I32 t = list_assignment(cCONDOP->op_first->op_sibling);
	I32 f = list_assignment(cCONDOP->op_first->op_sibling->op_sibling);

	if (t && f)
	    return TRUE;
	if (t || f)
	    yyerror("Assignment to both a list and a scalar");
	return FALSE;
    }

    if (op->op_type == OP_LIST || op->op_flags & OPf_PARENS ||
	op->op_type == OP_RV2AV || op->op_type == OP_RV2HV ||
	op->op_type == OP_ASLICE || op->op_type == OP_HSLICE)
	return TRUE;

    if (op->op_type == OP_PADAV || op->op_type == OP_PADHV)
	return TRUE;

    if (op->op_type == OP_RV2SV)
	return FALSE;

    return FALSE;
}

OP *
newASSIGNOP(flags, left, right)
I32 flags;
OP *left;
OP *right;
{
    OP *op;

    if (list_assignment(left)) {
	modcount = 0;
	left = mod(left, OP_AASSIGN);
	if (right && right->op_type == OP_SPLIT) {
	    if ((op = ((LISTOP*)right)->op_first) && op->op_type == OP_PUSHRE) {
		PMOP *pm = (PMOP*)op;
		if (left->op_type == OP_RV2AV) {
		    op = ((UNOP*)left)->op_first;
		    if (op->op_type == OP_GV && !pm->op_pmreplroot) {
			pm->op_pmreplroot = (OP*)((GVOP*)op)->op_gv;
			pm->op_pmflags |= PMf_ONCE;
			op_free(left);
			return right;
		    }
		}
		else {
		    if (modcount < 10000) {
			SV *sv = ((SVOP*)((LISTOP*)right)->op_last)->op_sv;
			if (SvIVX(sv) == 0)
			    sv_setiv(sv, modcount+1);
		    }
		}
	    }
	}
	op = newBINOP(OP_AASSIGN, flags,
		list(prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), right)),
		list(prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), left)) );
	op->op_private = 0;
	if (!(left->op_flags & OPf_INTRO)) {
	    static int generation = 0;
	    OP *curop;
	    OP *lastop = op;
	    generation++;
	    for (curop = LINKLIST(op); curop != op; curop = LINKLIST(curop)) {
		if (opargs[curop->op_type] & OA_DANGEROUS) {
		    if (curop->op_type == OP_GV) {
			GV *gv = ((GVOP*)curop)->op_gv;
			if (gv == defgv || SvCUR(gv) == generation)
			    break;
			SvCUR(gv) = generation;
		    }
		    else if (curop->op_type == OP_RV2CV)
			break;
		    else if (curop->op_type == OP_RV2SV ||
			     curop->op_type == OP_RV2AV ||
			     curop->op_type == OP_RV2HV ||
			     curop->op_type == OP_RV2GV) {
			if (lastop->op_type != OP_GV)	/* funny deref? */
			    break;
		    }
		    else
			break;
		}
		lastop = curop;
	    }
	    if (curop != op)
		op->op_private = OPpASSIGN_COMMON;
	}
	op->op_targ = pad_alloc(OP_AASSIGN, SVs_PADTMP);	/* for scalar context */
	return op;
    }
    if (!right)
	right = newOP(OP_UNDEF, 0);
    if (right->op_type == OP_READLINE) {
	right->op_flags |= OPf_STACKED;
	return newBINOP(OP_NULL, flags, mod(scalar(left), OP_SASSIGN), scalar(right));
    }
    else
	op = newBINOP(OP_SASSIGN, flags,
	    scalar(right), mod(scalar(left), OP_SASSIGN) );
    return op;
}

OP *
newSTATEOP(flags, label, op)
I32 flags;
char *label;
OP *op;
{
    register COP *cop;

    comppadnamefill = AvFILL(comppadname);	/* introduce my variables */

    Newz(1101, cop, 1, COP);
    cop->op_type = OP_NEXTSTATE;
    cop->op_ppaddr = ppaddr[ perldb ? OP_DBSTATE : OP_NEXTSTATE ];
    cop->op_flags = flags;
    cop->op_private = 0;
    cop->op_next = (OP*)cop;

    if (label) {
	cop->cop_label = label;
	needblockscope = TRUE;
    }
    cop->cop_seq = cop_seqmax++;

    if (copline == NOLINE)
        cop->cop_line = curcop->cop_line;
    else {
        cop->cop_line = copline;
        copline = NOLINE;
    }
    cop->cop_filegv = curcop->cop_filegv;
    cop->cop_stash = curstash;

    if (perldb) {
	SV **svp = av_fetch(GvAV(curcop->cop_filegv),(I32)cop->cop_line, FALSE);
	if (svp && *svp != &sv_undef && !SvIOK(*svp)) {
	    SvIVX(*svp) = 1;
	    SvIOK_on(*svp);
	    SvSTASH(*svp) = (HV*)cop;
	}
    }

    return prepend_elem(OP_LINESEQ, (OP*)cop, op);
}

OP *
newLOGOP(type, flags, first, other)
I32 type;
I32 flags;
OP* first;
OP* other;
{
    LOGOP *logop;
    OP *op;

    scalar(first);
    /* optimize "!a && b" to "a || b", and "!a || b" to "a && b" */
    if (first->op_type == OP_NOT && (first->op_flags & OPf_SPECIAL)) {
	if (type == OP_AND || type == OP_OR) {
	    if (type == OP_AND)
		type = OP_OR;
	    else
		type = OP_AND;
	    op = first;
	    first = cUNOP->op_first;
	    if (op->op_next)
		first->op_next = op->op_next;
	    cUNOP->op_first = Nullop;
	    op_free(op);
	}
    }
    if (first->op_type == OP_CONST) {
	if (dowarn && (first->op_private & OPpCONST_BARE))
	    warn("Probable precedence problem on %s", op_name[type]);
	if ((type == OP_AND) == (SvTRUE(((SVOP*)first)->op_sv))) {
	    op_free(first);
	    return other;
	}
	else {
	    op_free(other);
	    return first;
	}
    }
    else if (first->op_type == OP_WANTARRAY) {
	if (type == OP_AND)
	    list(other);
	else
	    scalar(other);
    }

    if (!other)
	return first;

    Newz(1101, logop, 1, LOGOP);

    logop->op_type = type;
    logop->op_ppaddr = ppaddr[type];
    logop->op_first = first;
    logop->op_flags = flags | OPf_KIDS;
    logop->op_other = LINKLIST(other);
    logop->op_private = 1;

    /* establish postfix order */
    logop->op_next = LINKLIST(first);
    first->op_next = (OP*)logop;
    first->op_sibling = other;

    op = newUNOP(OP_NULL, 0, (OP*)logop);
    other->op_next = op;

    return op;
}

OP *
newCONDOP(flags, first, true, false)
I32 flags;
OP* first;
OP* true;
OP* false;
{
    CONDOP *condop;
    OP *op;

    if (!false)
	return newLOGOP(OP_AND, 0, first, true);
    if (!true)
	return newLOGOP(OP_OR, 0, first, false);

    scalar(first);
    if (first->op_type == OP_CONST) {
	if (SvTRUE(((SVOP*)first)->op_sv)) {
	    op_free(first);
	    op_free(false);
	    return true;
	}
	else {
	    op_free(first);
	    op_free(true);
	    return false;
	}
    }
    else if (first->op_type == OP_WANTARRAY) {
	list(true);
	scalar(false);
    }
    Newz(1101, condop, 1, CONDOP);

    condop->op_type = OP_COND_EXPR;
    condop->op_ppaddr = ppaddr[OP_COND_EXPR];
    condop->op_first = first;
    condop->op_flags = flags | OPf_KIDS;
    condop->op_true = LINKLIST(true);
    condop->op_false = LINKLIST(false);
    condop->op_private = 1;

    /* establish postfix order */
    condop->op_next = LINKLIST(first);
    first->op_next = (OP*)condop;

    first->op_sibling = true;
    true->op_sibling = false;
    op = newUNOP(OP_NULL, 0, (OP*)condop);

    true->op_next = op;
    false->op_next = op;

    return op;
}

OP *
newRANGE(flags, left, right)
I32 flags;
OP *left;
OP *right;
{
    CONDOP *condop;
    OP *flip;
    OP *flop;
    OP *op;

    Newz(1101, condop, 1, CONDOP);

    condop->op_type = OP_RANGE;
    condop->op_ppaddr = ppaddr[OP_RANGE];
    condop->op_first = left;
    condop->op_flags = OPf_KIDS;
    condop->op_true = LINKLIST(left);
    condop->op_false = LINKLIST(right);
    condop->op_private = 1;

    left->op_sibling = right;

    condop->op_next = (OP*)condop;
    flip = newUNOP(OP_FLIP, flags, (OP*)condop);
    flop = newUNOP(OP_FLOP, 0, flip);
    op = newUNOP(OP_NULL, 0, flop);
    linklist(flop);

    left->op_next = flip;
    right->op_next = flop;

    condop->op_targ = pad_alloc(OP_RANGE, SVs_PADMY);
    sv_upgrade(PAD_SV(condop->op_targ), SVt_PVNV);
    flip->op_targ = pad_alloc(OP_RANGE, SVs_PADMY);
    sv_upgrade(PAD_SV(flip->op_targ), SVt_PVNV);

    flip->op_private =  left->op_type == OP_CONST ? OPpFLIP_LINENUM : 0;
    flop->op_private = right->op_type == OP_CONST ? OPpFLIP_LINENUM : 0;

    flip->op_next = op;
    if (!flip->op_private || !flop->op_private)
	linklist(op);		/* blow off optimizer unless constant */

    return op;
}

OP *
newLOOPOP(flags, debuggable, expr, block)
I32 flags;
I32 debuggable;
OP *expr;
OP *block;
{
    OP* listop;
    OP* op;
    int once = block && block->op_flags & OPf_SPECIAL &&
      (block->op_type == OP_ENTERSUBR || block->op_type == OP_NULL);

    if (expr) {
	if (once && expr->op_type == OP_CONST && !SvTRUE(((SVOP*)expr)->op_sv))
	    return block;	/* do {} while 0 does once */
	else if (expr->op_type == OP_READLINE || expr->op_type == OP_GLOB)
	    expr = newASSIGNOP(0, newSVREF(newGVOP(OP_GV, 0, defgv)), expr);
    }

    listop = append_elem(OP_LINESEQ, guess_mark(block), newOP(OP_UNSTACK, 0));
    op = newLOGOP(OP_AND, 0, expr, listop);

    ((LISTOP*)listop)->op_last->op_next = LINKLIST(op);

    if (once && op != listop)
	op->op_next = ((LOGOP*)cUNOP->op_first)->op_other;

    op->op_flags |= flags;
    return scope(op);
}

OP *
newWHILEOP(flags, debuggable, loop, expr, block, cont)
I32 flags;
I32 debuggable;
LOOP *loop;
OP *expr;
OP *block;
OP *cont;
{
    OP *redo;
    OP *next = 0;
    OP *listop;
    OP *op;
    OP *condop;

    if (expr && (expr->op_type == OP_READLINE || expr->op_type == OP_GLOB))
	expr = newASSIGNOP(0, newSVREF(newGVOP(OP_GV, 0, defgv)), expr);

    if (!block)
	block = newOP(OP_NULL, 0);

    if (cont)
	next = LINKLIST(cont);
    if (expr)
	cont = append_elem(OP_LINESEQ, cont, newOP(OP_UNSTACK, 0));

    listop = append_list(OP_LINESEQ, (LISTOP*)block, (LISTOP*)cont);
    redo = LINKLIST(listop);

    if (expr) {
	op = newLOGOP(OP_AND, 0, expr, scalar(listop));
	if (op == expr) {		/* oops, it's a while (0) */
	    op_free(expr);
	    op_free((OP*)loop);
	    return Nullop;		/* (listop already freed by newLOGOP) */
	}
	((LISTOP*)listop)->op_last->op_next = condop = 
	    (op == listop ? redo : LINKLIST(op));
	if (!next)
	    next = condop;
    }
    else
	op = listop;

    if (!loop) {
	Newz(1101,loop,1,LOOP);
	loop->op_type = OP_ENTERLOOP;
	loop->op_ppaddr = ppaddr[OP_ENTERLOOP];
	loop->op_private = 0;
	loop->op_next = (OP*)loop;
    }

    op = newBINOP(OP_LEAVELOOP, 0, (OP*)loop, op);

    loop->op_redoop = redo;
    loop->op_lastop = op;

    if (next)
	loop->op_nextop = next;
    else
	loop->op_nextop = op;

    op->op_flags |= flags;
    return op;
}

OP *
newFOROP(flags,label,forline,sv,expr,block,cont)
I32 flags;
char *label;
line_t forline;
OP* sv;
OP* expr;
OP*block;
OP*cont;
{
    LOOP *loop;

    copline = forline;
    if (sv) {
	if (sv->op_type == OP_RV2SV) {
	    OP *op = sv;
	    sv = cUNOP->op_first;
	    sv->op_next = sv;
	    cUNOP->op_first = Nullop;
	    op_free(op);
	}
	else
	    croak("Can't use %s for loop variable", op_name[sv->op_type]);
    }
    else {
	sv = newGVOP(OP_GV, 0, defgv);
    }
    loop = (LOOP*)list(convert(OP_ENTERITER, 0,
	append_elem(OP_LIST,
	    prepend_elem(OP_LIST, newOP(OP_PUSHMARK, 0), expr),
	    scalar(sv))));
    return newSTATEOP(0, label, newWHILEOP(flags, 1,
	loop, newOP(OP_ITER, 0), block, cont));
}

void
cv_clear(cv)
CV *cv;
{
    if (!CvUSERSUB(cv) && CvROOT(cv)) {
	op_free(CvROOT(cv));
	CvROOT(cv) = Nullop;
	if (CvDEPTH(cv))
	    warn("Deleting active subroutine");		/* XXX */
	if (CvPADLIST(cv)) {
	    I32 i = AvFILL(CvPADLIST(cv));
	    while (i > 0) {
		SV** svp = av_fetch(CvPADLIST(cv), i--, FALSE);
		if (svp)
		    av_free((AV*)*svp);
	    }
	    av_free((AV*)CvPADLIST(cv));
	}
    }
}

void
newSUB(floor,op,block)
I32 floor;
OP *op;
OP *block;
{
    register CV *cv;
    char *name = SvPVx(cSVOP->op_sv, na);
    GV *gv = gv_fetchpv(name,2);
    AV* av;

    sub_generation++;
    if ((cv = GvCV(gv)) && !GvCVGEN(gv)) {
	if (CvDEPTH(cv))
	    CvDELETED(cv) = TRUE;	/* probably an autoloader */
	else {
	    if (dowarn && CvROOT(cv)) {
		line_t oldline = curcop->cop_line;

		curcop->cop_line = copline;
		warn("Subroutine %s redefined",name);
		curcop->cop_line = oldline;
	    }
	    sv_free((SV*)cv);
	}
    }
    Newz(101,cv,1,CV);
    sv_upgrade(cv, SVt_PVCV);
    SvREFCNT(cv) = 1;
    GvCV(gv) = cv;
    GvCVGEN(gv) = 0;
    CvFILEGV(cv) = curcop->cop_filegv;

    av = newAV();
    AvREAL_off(av);
    if (AvFILL(comppadname) < AvFILL(comppad))
	av_store(comppadname, AvFILL(comppad), Nullsv);
    av_store(av, 0, (SV*)comppadname);
    av_store(av, 1, (SV*)comppad);
    AvFILL(av) = 1;
    CvPADLIST(cv) = av;
    comppadname = newAV();

    if (!block) {
	CvROOT(cv) = 0;
	op_free(op);
	copline = NOLINE;
	leave_scope(floor);
	return;
    }
    CvROOT(cv) = newUNOP(OP_LEAVESUBR, 0, scalarseq(block));
    CvSTART(cv) = LINKLIST(CvROOT(cv));
    CvROOT(cv)->op_next = 0;
    CvSTASH(cv) = curstash;
    peep(CvSTART(cv));
    CvDELETED(cv) = FALSE;
    if (strEQ(name, "BEGIN")) {
	line_t oldline = curcop->cop_line;
	GV* oldfile = curcop->cop_filegv;

	if (!beginav)
	    beginav = newAV();
	av_push(beginav, sv_ref(gv));
	DEBUG_x( dump_sub(gv) );
	rs = nrs;
	rslen = nrslen;
	rschar = nrschar;
	rspara = (nrslen == 2);
	calllist(beginav);
	sv_free((SV*)cv);
	rs = "\n";
	rslen = 1;
	rschar = '\n';
	rspara = 0;
	GvCV(gv) = 0;
	curcop = &compiling;
	curcop->cop_line = oldline;	/* might have compiled something */
	curcop->cop_filegv = oldfile;	/* recursively, clobbering these */
    }
    else if (strEQ(name, "END")) {
	if (!endav)
	    endav = newAV();
	av_unshift(endav, 1);
	av_store(endav, 0, sv_ref(gv));
    }
    if (perldb) {
	SV *sv;
	SV *tmpstr = sv_mortalcopy(&sv_undef);

	sprintf(buf,"%s:%ld",SvPVX(GvSV(curcop->cop_filegv)), subline);
	sv = newSVpv(buf,0);
	sv_catpv(sv,"-");
	sprintf(buf,"%ld",(long)curcop->cop_line);
	sv_catpv(sv,buf);
	gv_efullname(tmpstr,gv);
	hv_store(GvHV(DBsub), SvPVX(tmpstr), SvCUR(tmpstr), sv, 0);
    }
    op_free(op);
    copline = NOLINE;
    leave_scope(floor);
}

void
newXSUB(name, ix, subaddr, filename)
char *name;
I32 ix;
I32 (*subaddr)();
char *filename;
{
    register CV *cv;
    GV *gv = gv_fetchpv(name,2);

    sub_generation++;
    if ((cv = GvCV(gv)) && !GvCVGEN(gv)) {
	if (dowarn)
	    warn("Subroutine %s redefined",name);
	if (!CvUSERSUB(cv) && CvROOT(cv)) {
	    op_free(CvROOT(cv));
	    CvROOT(cv) = Nullop;
	}
	Safefree(cv);
    }
    Newz(101,cv,1,CV);
    sv_upgrade(cv, SVt_PVCV);
    SvREFCNT(cv) = 1;
    GvCV(gv) = cv;
    GvCVGEN(gv) = 0;
    CvFILEGV(cv) = gv_fetchfile(filename);
    CvUSERSUB(cv) = subaddr;
    CvUSERINDEX(cv) = ix;
    CvDELETED(cv) = FALSE;
    if (strEQ(name, "BEGIN")) {
	if (!beginav)
	    beginav = newAV();
	av_push(beginav, sv_ref(gv));
    }
    else if (strEQ(name, "END")) {
	if (!endav)
	    endav = newAV();
	av_unshift(endav, 1);
	av_store(endav, 0, sv_ref(gv));
    }
}

void
newFORM(floor,op,block)
I32 floor;
OP *op;
OP *block;
{
    register CV *cv;
    char *name;
    GV *gv;
    AV* av;

    if (op)
	name = SvPVx(cSVOP->op_sv, na);
    else
	name = "STDOUT";
    gv = gv_fetchpv(name,TRUE);
    if (cv = GvFORM(gv)) {
	if (dowarn) {
	    line_t oldline = curcop->cop_line;

	    curcop->cop_line = copline;
	    warn("Format %s redefined",name);
	    curcop->cop_line = oldline;
	}
	sv_free((SV*)cv);
    }
    Newz(101,cv,1,CV);
    sv_upgrade(cv, SVt_PVFM);
    SvREFCNT(cv) = 1;
    GvFORM(gv) = cv;
    CvFILEGV(cv) = curcop->cop_filegv;

    CvPADLIST(cv) = av = newAV();
    AvREAL_off(av);
    av_store(av, 1, (SV*)comppad);
    AvFILL(av) = 1;

    CvROOT(cv) = newUNOP(OP_LEAVEWRITE, 0, scalarseq(block));
    CvSTART(cv) = LINKLIST(CvROOT(cv));
    CvROOT(cv)->op_next = 0;
    peep(CvSTART(cv));
    CvDELETED(cv) = FALSE;
    FmLINES(cv) = 0;
    op_free(op);
    copline = NOLINE;
    leave_scope(floor);
}

OP *
newMETHOD(ref,name)
OP *ref;
OP *name;
{
    LOGOP* mop;
    Newz(1101, mop, 1, LOGOP);
    mop->op_type = OP_METHOD;
    mop->op_ppaddr = ppaddr[OP_METHOD];
    mop->op_first = scalar(ref);
    mop->op_flags |= OPf_KIDS;
    mop->op_private = 1;
    mop->op_other = LINKLIST(name);
    mop->op_targ = pad_alloc(OP_METHOD, SVs_PADTMP);
    mop->op_next = LINKLIST(ref);
    ref->op_next = (OP*)mop;
    return (OP*)mop;
}

OP *
newANONLIST(op)
OP* op;
{
    return newUNOP(OP_REFGEN, 0,
	ref(list(convert(OP_ANONLIST, 0, op)), OP_REFGEN));
}

OP *
newANONHASH(op)
OP* op;
{
    return newUNOP(OP_REFGEN, 0,
	ref(list(convert(OP_ANONHASH, 0, op)), OP_REFGEN));
}

OP *
oopsAV(o)
OP *o;
{
    switch (o->op_type) {
    case OP_PADSV:
	o->op_type = OP_PADAV;
	o->op_ppaddr = ppaddr[OP_PADAV];
	return ref(newUNOP(OP_RV2AV, 0, scalar(o)), OP_RV2AV);
	
    case OP_RV2SV:
	o->op_type = OP_RV2AV;
	o->op_ppaddr = ppaddr[OP_RV2AV];
	ref(o, OP_RV2AV);
	break;

    default:
	warn("oops: oopsAV");
	break;
    }
    return o;
}

OP *
oopsHV(o)
OP *o;
{
    switch (o->op_type) {
    case OP_PADSV:
    case OP_PADAV:
	o->op_type = OP_PADHV;
	o->op_ppaddr = ppaddr[OP_PADHV];
	return ref(newUNOP(OP_RV2HV, 0, scalar(o)), OP_RV2HV);

    case OP_RV2SV:
    case OP_RV2AV:
	o->op_type = OP_RV2HV;
	o->op_ppaddr = ppaddr[OP_RV2HV];
	ref(o, OP_RV2HV);
	break;

    default:
	warn("oops: oopsHV");
	break;
    }
    return o;
}

OP *
newAVREF(o)
OP *o;
{
    if (o->op_type == OP_PADANY) {
	o->op_type = OP_PADAV;
	o->op_ppaddr = ppaddr[OP_PADAV];
	return o;
    }
    return newUNOP(OP_RV2AV, 0, scalar(o));
}

OP *
newGVREF(o)
OP *o;
{
    return newUNOP(OP_RV2GV, 0, scalar(o));
}

OP *
newHVREF(o)
OP *o;
{
    if (o->op_type == OP_PADANY) {
	o->op_type = OP_PADHV;
	o->op_ppaddr = ppaddr[OP_PADHV];
	return o;
    }
    return newUNOP(OP_RV2HV, 0, scalar(o));
}

OP *
oopsCV(o)
OP *o;
{
    croak("NOT IMPL LINE %d",__LINE__);
    /* STUB */
    return o;
}

OP *
newCVREF(o)
OP *o;
{
    return newUNOP(OP_RV2CV, 0, scalar(o));
}

OP *
newSVREF(o)
OP *o;
{
    if (o->op_type == OP_PADANY) {
	o->op_type = OP_PADSV;
	o->op_ppaddr = ppaddr[OP_PADSV];
	return o;
    }
    return newUNOP(OP_RV2SV, 0, scalar(o));
}

/* Check routines. */

OP *
ck_aelem(op)
OP *op;
{
    /* XXX need to optimize constant subscript here. */
    return op;
}

OP *
ck_concat(op)
OP *op;
{
    if (cUNOP->op_first->op_type == OP_CONCAT)
	op->op_flags |= OPf_STACKED;
    return op;
}

OP *
ck_chop(op)
OP *op;
{
    if (op->op_flags & OPf_KIDS) {
	OP* newop;
	op = modkids(ck_fun(op), op->op_type);
	if (op->op_private != 1)
	    return op;
	newop = cUNOP->op_first->op_sibling;
	if (!newop || newop->op_type != OP_RV2SV)
	    return op;
	op_free(cUNOP->op_first);
	cUNOP->op_first = newop;
    }
    op->op_type = OP_SCHOP;
    op->op_ppaddr = ppaddr[OP_SCHOP];
    return op;
}

OP *
ck_eof(op)
OP *op;
{
    I32 type = op->op_type;

    if (op->op_flags & OPf_KIDS)
	return ck_fun(op);

    if (op->op_flags & OPf_SPECIAL) {
	op_free(op);
	op = newUNOP(type, 0, newGVOP(OP_GV, 0, gv_fetchpv("main'ARGV", TRUE)));
    }
    return op;
}

OP *
ck_eval(op)
OP *op;
{
    needblockscope = TRUE;
    if (op->op_flags & OPf_KIDS) {
	SVOP *kid = (SVOP*)cUNOP->op_first;

	if (!kid) {
	    op->op_flags &= ~OPf_KIDS;
	    op->op_type = OP_NULL;
	    op->op_ppaddr = ppaddr[OP_NULL];
	}
	else if (kid->op_type == OP_LINESEQ) {
	    LOGOP *enter;

	    kid->op_next = op->op_next;
	    cUNOP->op_first = 0;
	    op_free(op);

	    Newz(1101, enter, 1, LOGOP);
	    enter->op_type = OP_ENTERTRY;
	    enter->op_ppaddr = ppaddr[OP_ENTERTRY];
	    enter->op_private = 0;

	    /* establish postfix order */
	    enter->op_next = (OP*)enter;

	    op = prepend_elem(OP_LINESEQ, (OP*)enter, (OP*)kid);
	    op->op_type = OP_LEAVETRY;
	    op->op_ppaddr = ppaddr[OP_LEAVETRY];
	    enter->op_other = op;
	    return op;
	}
    }
    else {
	op_free(op);
	op = newUNOP(OP_ENTEREVAL, 0, newSVREF(newGVOP(OP_GV, 0, defgv)));
    }
    return op;
}

OP *
ck_exec(op)
OP *op;
{
    OP *kid;
    if (op->op_flags & OPf_STACKED) {
	op = ck_fun(op);
	kid = cUNOP->op_first->op_sibling;
	if (kid->op_type == OP_RV2GV) {
	    kid->op_type = OP_NULL;
	    kid->op_ppaddr = ppaddr[OP_NULL];
	}
    }
    else
	op = listkids(op);
    return op;
}

OP *
ck_gvconst(o)
register OP *o;
{
    o = fold_constants(o);
    if (o->op_type == OP_CONST)
	o->op_type = OP_GV;
    return o;
}

OP *
ck_rvconst(op)
register OP *op;
{
    SVOP *kid = (SVOP*)cUNOP->op_first;
    if (kid->op_type == OP_CONST) {
	kid->op_type = OP_GV;
	kid->op_sv = sv_ref((SV*)gv_fetchpv(SvPVx(kid->op_sv, na),
		1+(op->op_type==OP_RV2CV)));
    }
    return op;
}

OP *
ck_formline(op)
OP *op;
{
    return ck_fun(op);
}

OP *
ck_ftst(op)
OP *op;
{
    I32 type = op->op_type;

    if (op->op_flags & OPf_SPECIAL)
	return op;

    if (op->op_flags & OPf_KIDS) {
	SVOP *kid = (SVOP*)cUNOP->op_first;

	if (kid->op_type == OP_CONST && (kid->op_private & OPpCONST_BARE)) {
	    OP *newop = newGVOP(type, OPf_SPECIAL,
		gv_fetchpv(SvPVx(kid->op_sv, na), TRUE));
	    op_free(op);
	    return newop;
	}
    }
    else {
	op_free(op);
	if (type == OP_FTTTY)
	    return newGVOP(type, OPf_SPECIAL, gv_fetchpv("main'STDIN", TRUE));
	else
	    return newUNOP(type, 0, newSVREF(newGVOP(OP_GV, 0, defgv)));
    }
    return op;
}

OP *
ck_fun(op)
OP *op;
{
    register OP *kid;
    OP **tokid;
    OP *sibl;
    I32 numargs = 0;
    register I32 oa = opargs[op->op_type] >> 8;
    
    if (op->op_flags & OPf_STACKED) {
	if ((oa & OA_OPTIONAL) && (oa >> 4) && !((oa >> 4) & OA_OPTIONAL))
	    oa &= ~OA_OPTIONAL;
	else
	    return no_fh_allowed(op);
    }

    if (op->op_flags & OPf_KIDS) {
	tokid = &cLISTOP->op_first;
	kid = cLISTOP->op_first;
	if (kid->op_type == OP_PUSHMARK) {
	    tokid = &kid->op_sibling;
	    kid = kid->op_sibling;
	}

	while (oa && kid) {
	    numargs++;
	    sibl = kid->op_sibling;
	    switch (oa & 7) {
	    case OA_SCALAR:
		scalar(kid);
		break;
	    case OA_LIST:
		if (oa < 16) {
		    kid = 0;
		    continue;
		}
		else
		    list(kid);
		break;
	    case OA_AVREF:
		if (kid->op_type == OP_CONST &&
		  (kid->op_private & OPpCONST_BARE)) {
		    char *name = SvPVx(((SVOP*)kid)->op_sv, na);
		    OP *newop = newAVREF(newGVOP(OP_GV, 0,
			gv_fetchpv(name, TRUE) ));
		    if (dowarn)
			warn("Array @%s missing the @ in argument %d of %s()",
			    name, numargs, op_name[op->op_type]);
		    op_free(kid);
		    kid = newop;
		    kid->op_sibling = sibl;
		    *tokid = kid;
		}
		mod(kid, op->op_type);
		break;
	    case OA_HVREF:
		if (kid->op_type == OP_CONST &&
		  (kid->op_private & OPpCONST_BARE)) {
		    char *name = SvPVx(((SVOP*)kid)->op_sv, na);
		    OP *newop = newHVREF(newGVOP(OP_GV, 0,
			gv_fetchpv(name, TRUE) ));
		    if (dowarn)
			warn("Hash %%%s missing the %% in argument %d of %s()",
			    name, numargs, op_name[op->op_type]);
		    op_free(kid);
		    kid = newop;
		    kid->op_sibling = sibl;
		    *tokid = kid;
		}
		mod(kid, op->op_type);
		break;
	    case OA_CVREF:
		{
		    OP *newop = newUNOP(OP_NULL, 0, scalar(kid));
		    kid->op_sibling = 0;
		    linklist(kid);
		    newop->op_next = newop;
		    kid = newop;
		    kid->op_sibling = sibl;
		    *tokid = kid;
		}
		break;
	    case OA_FILEREF:
		if (kid->op_type != OP_GV) {
		    if (kid->op_type == OP_CONST &&
		      (kid->op_private & OPpCONST_BARE)) {
			OP *newop = newGVOP(OP_GV, 0,
			    gv_fetchpv(SvPVx(((SVOP*)kid)->op_sv, na), TRUE) );
			op_free(kid);
			kid = newop;
		    }
		    else {
			kid->op_sibling = 0;
			kid = newUNOP(OP_RV2GV, 0, scalar(kid));
		    }
		    kid->op_sibling = sibl;
		    *tokid = kid;
		}
		scalar(kid);
		break;
	    case OA_SCALARREF:
		mod(scalar(kid), op->op_type);
		break;
	    }
	    oa >>= 4;
	    tokid = &kid->op_sibling;
	    kid = kid->op_sibling;
	}
	op->op_private = numargs;
	if (kid)
	    return too_many_arguments(op);
	listkids(op);
    }
    if (oa) {
	while (oa & OA_OPTIONAL)
	    oa >>= 4;
	if (oa && oa != OA_LIST)
	    return too_few_arguments(op);
    }
    return op;
}

OP *
ck_glob(op)
OP *op;
{
    GV *gv = newGVgen();
    GvIOn(gv);
    append_elem(OP_GLOB, op, newGVOP(OP_GV, 0, gv));
    scalarkids(op);
    return op;
}

OP *
ck_grep(op)
OP *op;
{
    LOGOP *gwop;
    OP *kid;

    if (op->op_flags & OPf_STACKED) {
	op = ck_sort(op);
	op->op_flags &= ~OPf_STACKED;
    }
    op = ck_fun(op);
    if (error_count)
	return op;
    kid = cLISTOP->op_first->op_sibling;
    if (kid->op_type != OP_NULL)
	croak("panic: ck_grep");
    kid = kUNOP->op_first;

    Newz(1101, gwop, 1, LOGOP);
    gwop->op_type = OP_GREPWHILE;
    gwop->op_ppaddr = ppaddr[OP_GREPWHILE];
    gwop->op_first = list(op);
    gwop->op_flags |= OPf_KIDS;
    gwop->op_private = 1;
    gwop->op_other = LINKLIST(kid);
    gwop->op_targ = pad_alloc(OP_GREPWHILE, SVs_PADTMP);
    kid->op_next = (OP*)gwop;

    return (OP*)gwop;
}

OP *
ck_index(op)
OP *op;
{
    if (op->op_flags & OPf_KIDS) {
	OP *kid = cLISTOP->op_first->op_sibling;	/* get past pushmark */
	if (kid && kid->op_type == OP_CONST)
	    fbm_compile(((SVOP*)kid)->op_sv, 0);
    }
    return ck_fun(op);
}

OP *
ck_lengthconst(op)
OP *op;
{
    /* XXX length optimization goes here */
    return op;
}

OP *
ck_lfun(op)
OP *op;
{
    return modkids(ck_fun(op), op->op_type);
}

OP *
ck_listiob(op)
OP *op;
{
    register OP *kid;
    
    kid = cLISTOP->op_first;
    if (!kid) {
	prepend_elem(op->op_type, newOP(OP_PUSHMARK, 0), op);
	kid = cLISTOP->op_first;
    }
    if (kid->op_type == OP_PUSHMARK)
	kid = kid->op_sibling;
    if (kid && op->op_flags & OPf_STACKED)
	kid = kid->op_sibling;
    else if (kid && !kid->op_sibling) {		/* print HANDLE; */
	if (kid->op_type == OP_CONST && kid->op_private & OPpCONST_BARE) {
	    op->op_flags |= OPf_STACKED;	/* make it a filehandle */
	    kid = newUNOP(OP_RV2GV, 0, scalar(kid));
	    cLISTOP->op_first->op_sibling = kid;
	    cLISTOP->op_last = kid;
	    kid = kid->op_sibling;
	}
    }
	
    if (!kid)
	append_elem(op->op_type, op, newSVREF(newGVOP(OP_GV, 0, defgv)) );

    return listkids(op);
}

OP *
ck_match(op)
OP *op;
{
    cPMOP->op_pmflags |= PMf_RUNTIME;
    return op;
}

OP *
ck_null(op)
OP *op;
{
    return op;
}

OP *
ck_repeat(op)
OP *op;
{
    if (cBINOP->op_first->op_flags & OPf_PARENS) {
	op->op_private = OPpREPEAT_DOLIST;
	cBINOP->op_first =
		prepend_elem(OP_NULL, newOP(OP_PUSHMARK, 0), cBINOP->op_first);
    }
    else
	scalar(op);
    return op;
}

OP *
ck_retarget(op)
OP *op;
{
    croak("NOT IMPL LINE %d",__LINE__);
    /* STUB */
    return op;
}

OP *
ck_select(op)
OP *op;
{
    if (op->op_flags & OPf_KIDS) {
	OP *kid = cLISTOP->op_first->op_sibling;	/* get past pushmark */
	if (kid) {
	    op->op_type = OP_SSELECT;
	    op->op_ppaddr = ppaddr[OP_SSELECT];
	    op = ck_fun(op);
	    return fold_constants(op);
	}
    }
    return ck_fun(op);
}

OP *
ck_shift(op)
OP *op;
{
    I32 type = op->op_type;

    if (!(op->op_flags & OPf_KIDS)) {
	op_free(op);
	return newUNOP(type, 0,
	    scalar(newUNOP(OP_RV2AV, 0,
		scalar(newGVOP(OP_GV, 0,
		    gv_fetchpv((subline ? "_" : "ARGV"), TRUE) )))));
    }
    return scalar(modkids(ck_fun(op), type));
}

OP *
ck_sort(op)
OP *op;
{
    if (op->op_flags & OPf_STACKED) {
	OP *kid = cLISTOP->op_first->op_sibling;	/* get past pushmark */
	OP *k;
	kid = kUNOP->op_first;				/* get past rv2gv */

	if (kid->op_type == OP_SCOPE || kid->op_type == OP_LEAVE) {
	    linklist(kid);
	    if (kid->op_type == OP_SCOPE) {
		k = kid->op_next;
		kid->op_next = 0;
		peep(k);
	    }
	    else if (kid->op_type == OP_LEAVE) {
		kid->op_type = OP_NULL;			/* wipe out leave */
		kid->op_ppaddr = ppaddr[OP_NULL];
		kid->op_next = kid;

		for (k = kLISTOP->op_first->op_next; k; k = k->op_next) {
		    if (k->op_next == kid)
			k->op_next = 0;
		}
		peep(kLISTOP->op_first);
	    }
	    kid = cLISTOP->op_first->op_sibling;	/* get past pushmark */
	    kid->op_type = OP_NULL;			/* wipe out rv2gv */
	    kid->op_ppaddr = ppaddr[OP_NULL];
	    kid->op_next = kid;
	    op->op_flags |= OPf_SPECIAL;
	}
    }
    return op;
}

OP *
ck_split(op)
OP *op;
{
    register OP *kid;
    PMOP* pm;
    
    if (op->op_flags & OPf_STACKED)
	return no_fh_allowed(op);

    if (!(op->op_flags & OPf_KIDS))
	op = prepend_elem(OP_SPLIT,
	    pmruntime(
		newPMOP(OP_MATCH, OPf_SPECIAL),
		newSVOP(OP_CONST, 0, newSVpv(" ", 1)),
		Nullop),
	    op);

    kid = cLISTOP->op_first;
    if (kid->op_type == OP_PUSHMARK)
	croak("panic: ck_split");

    if (kid->op_type != OP_MATCH) {
	OP *sibl = kid->op_sibling;
	kid->op_sibling = 0;
	kid = pmruntime( newPMOP(OP_MATCH, OPf_SPECIAL), kid, Nullop);
	if (cLISTOP->op_first == cLISTOP->op_last)
	    cLISTOP->op_last = kid;
	cLISTOP->op_first = kid;
	kid->op_sibling = sibl;
    }
    pm = (PMOP*)kid;
    if (pm->op_pmshort && !(pm->op_pmflags & PMf_ALL)) {
	sv_free(pm->op_pmshort);	/* can't use substring to optimize */
	pm->op_pmshort = 0;
    }

    kid->op_type = OP_PUSHRE;
    kid->op_ppaddr = ppaddr[OP_PUSHRE];
    scalar(kid);

    if (!kid->op_sibling)
	append_elem(OP_SPLIT, op, newSVREF(newGVOP(OP_GV, 0, defgv)) );

    kid = kid->op_sibling;
    scalar(kid);

    if (!kid->op_sibling)
	append_elem(OP_SPLIT, op, newSVOP(OP_CONST, 0, newSViv(0)));

    kid = kid->op_sibling;
    scalar(kid);

    if (kid->op_sibling)
	return too_many_arguments(op);

    return op;
}

OP *
ck_subr(op)
OP *op;
{
    OP *o = ((cUNOP->op_first->op_sibling)
	     ? cUNOP : ((UNOP*)cUNOP->op_first))->op_first->op_sibling;

    if (o->op_type == OP_RV2CV) {
	o->op_type = OP_NULL;		/* disable rv2cv */
	o->op_ppaddr = ppaddr[OP_NULL];
    }
    op->op_private = 0;
    if (perldb)
	op->op_private |= OPpSUBR_DB;
    return op;
}

OP *
ck_trunc(op)
OP *op;
{
    if (op->op_flags & OPf_KIDS) {
	SVOP *kid = (SVOP*)cUNOP->op_first;

	if (kid->op_type == OP_CONST && (kid->op_private & OPpCONST_BARE))
	    op->op_flags |= OPf_SPECIAL;
    }
    return ck_fun(op);
}

/* A peephole optimizer.  We visit the ops in the order they're to execute. */

void
peep(op)
register OP* op;
{
    register OP* oldop = 0;
    if (!op || op->op_seq)
	return;
    for (; op; op = op->op_next) {
	if (op->op_seq)
	    return;
	switch (op->op_type) {
	case OP_NULL:
	case OP_SCALAR:
	case OP_LINESEQ:
	case OP_SCOPE:
	    if (oldop) {
		oldop->op_next = op->op_next;
		continue;
	    }
	    op->op_seq = ++op_seqmax;
	    break;

	case OP_GV:
	    if (op->op_next->op_type == OP_RV2SV &&
		op->op_next->op_private < OP_RV2GV)
	    {
		op->op_next->op_type = OP_NULL;
		op->op_next->op_ppaddr = ppaddr[OP_NULL];
		op->op_flags |= op->op_next->op_flags & OPf_INTRO;
		op->op_next = op->op_next->op_next;
		op->op_type = OP_GVSV;
		op->op_ppaddr = ppaddr[OP_GVSV];
	    }
	    op->op_seq = ++op_seqmax;
	    break;

	case OP_GREPWHILE:
	case OP_AND:
	case OP_OR:
	    op->op_seq = ++op_seqmax;
	    peep(cLOGOP->op_other);
	    break;

	case OP_COND_EXPR:
	    op->op_seq = ++op_seqmax;
	    peep(cCONDOP->op_true);
	    peep(cCONDOP->op_false);
	    break;

	case OP_ENTERLOOP:
	    op->op_seq = ++op_seqmax;
	    peep(cLOOP->op_redoop);
	    peep(cLOOP->op_nextop);
	    peep(cLOOP->op_lastop);
	    break;

	case OP_MATCH:
	case OP_SUBST:
	    op->op_seq = ++op_seqmax;
	    peep(cPMOP->op_pmreplroot);
	    break;

	default:
	    op->op_seq = ++op_seqmax;
	    break;
	}
	oldop = op;
    }
}
