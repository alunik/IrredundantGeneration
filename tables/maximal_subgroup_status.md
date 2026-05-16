# Maximal subgroup status and strong flatness

This file records the subgroup information used to determine `i(G)` and to
discuss strong flatness.  It is deliberately more conservative than a table of
exact triples for every maximal subgroup class: in most rows the certificate is
an upper bound for all subgroups lying below a maximal subgroup class, together
with equality witnesses when they were needed or found.

Throughout, `MaxDim` means the weak/private-witness maximal-subgroup dimension
used in the paper.  A weak-GP `r` witness in a subgroup `K` proves
`i(K) >= r`; a no-weak-GP `r+1` certificate for every subgroup below a maximal
class proves that all those subgroups have `i <= r`.

## Ambient values

| group | `m(G)` | `MaxDim(G)` | `i(G)` | flat? |
| --- | ---: | ---: | ---: | --- |
| `J1` | 4 | 4 | 4 | yes |
| `J2` | 5 | 5 | 5 | yes |
| `J3` | 4 | 4 | 5 | no |
| `M22` | 6 | 6 | 6 | yes |
| `M23` | 6 | 6 | 6 | yes |
| `M24` | 7 | 7 | 7 | yes |
| `HS` | 7 | 7 | 7 | yes |
| `McL` | 6 | 6 | 6 | yes |

The rows `M11` and `M12`, used in the paper but not recomputed here, are taken
from Brooks for `m` and `i`, and from Liu--Dennis for `MaxDim`:

| group | `m(G)` | `MaxDim(G)` | `i(G)` |
| --- | ---: | ---: | ---: |
| `M11` | 5 | 5 | 5 |
| `M12` | 6 | 6 | 6 |

## Strong flatness summary

Here "strongly flat" means that every proper subgroup `H < G` satisfies
`i(H) < m(G)`.

| group | proper-subgroup certificate | strongly flat? |
| --- | --- | --- |
| `M11` | Brooks proves the proper-subgroup bound. | yes |
| `M12` | Brooks proves the proper-subgroup bound. | yes |
| `J1` | `logs/j1_i_upper.log` proves all proper subgroups have `i <= 4` and finds weak-GP4 witnesses in proper subgroups such as `PSL(2,11)`. | no |
| `M22` | `logs/m22_i_upper_strong_flat.log` proves every proper subgroup has `i <= 5`. | yes |
| `J2` | `logs/j2_i_upper.log` proves all proper subgroups have `i <= 5` and finds weak-GP5 witnesses in proper subgroups such as `C2 x C2 x A5`. | no |
| `M23` | `M22 < M23` and `i(M22)=6`. | no |
| `HS` | `logs/hs_member_i7_filter_current.log` finds a weak-GP7 witness in the maximal subgroup `S8`. | no |
| `J3` | `certs/j3_i5_irredundant_tuple.json` gives an irredundant set of length 5 in a proper subgroup `2^4:GL(2,4)`. | no |
| `M24` | The release certificates prove all proper subgroups have `i <= 7`; they do not certify whether some proper subgroup has `i=7`. | not decided here |
| `McL` | `logs/mcl_member_i6_filter.log` and `logs/u43_member_i6_filter.log` find weak-GP6 witnesses below `U4(3) < McL`. | no |

## Maximal subgroup class status

Class numbers are those printed by the corresponding GAP run.  They are
interpreted relative to the `MaximalSubgroupClassReps(G)` table in the same
log, not as intrinsic labels independent of the GAP session.

### `J1`

Source: `logs/j1_i_upper.log`.

All proper subgroups have no weak-GP5 family, hence `i(H) <= 4` for every
proper `H < J1`.  The same run finds weak-GP4 witnesses below maximal classes
1, 3, and 6.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `PSL(2,11)` | contains weak-GP4 witness |
| 2 | `(C2 x C2 x C2) : (C7 : C3)` | no subgroup weak-GP5 |
| 3 | `C2 x A5` | contains weak-GP4 witness |
| 4 | `C19 : C6` | no subgroup weak-GP5 |
| 5 | `C11 : C10` | no subgroup weak-GP5 |
| 6 | `S3 x D10` | contains weak-GP4 witness |
| 7 | `C7 : C6` | no subgroup weak-GP5 |

### `J2`

Source: `logs/j2_i_upper.log`.

All proper subgroups have no weak-GP6 family, hence `i(H) <= 5` for every
proper `H < J2`.  The same run finds weak-GP5 witnesses below maximal classes
5 and 6.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `PSU(3,3)` | no subgroup weak-GP6 |
| 2 | `(C3 . A6) : C2` | no subgroup weak-GP6 |
| 3 | `((C2 x Q8) : C2) : A5` | no subgroup weak-GP6 |
| 4 | `2^4 : 2^2 : 3 : 2 : 3` | no subgroup weak-GP6 |
| 5 | `A5 x A4` | contains weak-GP5 witness |
| 6 | `A5 x D10` | contains weak-GP5 witness |
| 7 | `PSL(3,2) : C2` | no subgroup weak-GP6 |
| 8 | `(C5 x C5) : D12` | no subgroup weak-GP6 |
| 9 | `A5` | no subgroup weak-GP6 |

### `J3`

Sources: `logs/j3_proper_i_upper_target6.log`,
`certs/j3_i5_irredundant_tuple.json`.

All proper subgroups have no weak-GP6 family, hence `i(H) <= 5` for every
proper `H < J3`.  A length-5 irredundant set lies in a subgroup
`2^4:GL(2,4)` below maximal class 4.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `PSL(2,16) : C2` | no subgroup weak-GP6 |
| 2 | `PSL(2,19)` | no subgroup weak-GP6 |
| 3 | `PSL(2,19)` | no subgroup weak-GP6 |
| 4 | `(C2 x C2 x C2 x C2) : GL(2,4)` | contains the length-5 irredundant witness |
| 5 | `PSL(2,17)` | no subgroup weak-GP6 |
| 6 | `C3 : (A6 : C2)` | no subgroup weak-GP6 |
| 7 | `3^2 . 3^3 : C8` | no subgroup weak-GP6 |
| 8 | `((C2 x Q8) : C2) : A5` | no subgroup weak-GP6 |
| 9 | `2^4 : 2^2 : 3^2 : 2` | no subgroup weak-GP6 |

### `M22`

Source: `logs/m22_i_upper_strong_flat.log`.

Every proper subgroup has `i <= 5`.  Since `m(M22)=6`, this proves `M22` is
strongly flat.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `PSL(3,4)` | no subgroup weak-GP6 |
| 2 | `(C2 x C2 x C2 x C2) : A6` | no subgroup weak-GP6 |
| 3 | `A7` | no subgroup weak-GP6 |
| 4 | `A7` | no subgroup weak-GP6 |
| 5 | `(C2 x C2 x C2 x C2) : S5` | no subgroup weak-GP6 |
| 6 | `(C2 x C2 x C2) : PSL(3,2)` | no subgroup weak-GP6 |
| 7 | `A6 . C2` | no subgroup weak-GP6 |
| 8 | `PSL(2,11)` | no subgroup weak-GP6 |

### `M23`

Source: `logs/m23_proper_i_upper.log`.

Class 1 is `M22`, so the previous `i(M22)=6` result gives a proper subgroup
with the same `i` value as `m(M23)`.  For all non-`M22` maximal classes, the
log proves no subgroup below that class has weak-GP7.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `M22` | exact `i=6` from the `M22` computation |
| 2 | `PSL(3,4) : C2` | no subgroup weak-GP7 |
| 3 | `(C2 x C2 x C2 x C2) : A7` | no subgroup weak-GP7 |
| 4 | `A8` | no subgroup weak-GP7 |
| 5 | `M11` | no subgroup weak-GP7 |
| 6 | `(C2 x C2 x C2 x C2) : (A5 : S3)` | no subgroup weak-GP7 |
| 7 | `C23 : C11` | no subgroup weak-GP7 |

### `M24`

Sources: `certs/m24_i_upper_manifest.json`,
`logs/m24_i_upper_manifest_validation.log`.

The release certificates prove that every proper subgroup has `i <= 7`, which
is enough for `i(M24)=7` because the explicit generating tuple has length 7.
They do not, by themselves, decide whether a proper subgroup has `i=7`; hence
strong flatness for `M24` is not asserted here.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `M23` | exact `i=6` from the `M23` computation |
| 2 | `M22 : C2` | no subgroup weak-GP8 |
| 3 | `(C2 x C2 x C2 x C2) : A8` | no subgroup weak-GP8 |
| 4 | `M12 : C2` | no subgroup weak-GP8, and no subgroup weak-GP7 in the ambient-exclusion run |
| 5 | `2^6 : ((C3 . A6) : C2)` | no subgroup weak-GP8 |
| 6 | `PSL(3,4) : S3` | no subgroup weak-GP8, and no subgroup weak-GP7 in the ambient-exclusion run |
| 7 | `2^6 : (S3 x PSL(3,2))` | no subgroup weak-GP8 |
| 8 | `PSL(2,23)` | no subgroup weak-GP8, and no subgroup weak-GP7 in the ambient-exclusion run |
| 9 | `PSL(3,2)` | no subgroup weak-GP8, and no subgroup weak-GP7 in the ambient-exclusion run |

### `HS`

Sources: `logs/hs_member_i7_filter_current.log`,
`logs/hs_current_no_gp8_class5.log`,
`logs/hs_i_upper_manifest.md`.

The proper-subgroup manifest proves every proper subgroup has `i <= 7`.
The member filter finds a weak-GP7 witness in class 5, the maximal subgroup
`S8`, so `HS` is flat but not strongly flat.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `M22` | known `i=6`; excluded for weak-GP7 membership |
| 2 | `PSU(3,5) : C2` | no subgroup weak-GP7 |
| 3 | `PSU(3,5) : C2` | no subgroup weak-GP7 |
| 4 | `PSL(3,4) : C2` | no subgroup weak-GP7 |
| 5 | `S8` | contains weak-GP7 witness; no weak-GP8 in class-5 ambient search |
| 6 | `2^4 : A6 : C2` | no subgroup weak-GP7 |
| 7 | `(C4 x C4 x C4) : PSL(3,2)` | no subgroup weak-GP7 |
| 8 | `M11` | known `i=5`; excluded for weak-GP7 membership |
| 9 | `M11` | known `i=5`; excluded for weak-GP7 membership |
| 10 | `2`-local subgroup of order 7680 | no subgroup weak-GP7 |
| 11 | `C2 x ((A6 : C2) : C2)` | no subgroup weak-GP7 |
| 12 | `A5 x (C5 : C4)` | no subgroup weak-GP7 |

### `McL`

Sources: `logs/mcl_member_i6_filter.log`, `logs/mcl_i_upper_manifest.md`,
`logs/u43_member_i6_filter.log`, `logs/u43_proper_i_upper_target7.log`.

The proper-subgroup manifest proves every proper subgroup has `i <= 6`.
Weak-GP6 witnesses occur below class 1 (`U4(3)`) and several other maximal
classes, so `McL` is flat but not strongly flat.

| class | structure | subgroup status |
| ---: | --- | --- |
| 1 | `PSU(4,3)` | contains weak-GP6 witness below a subgroup of order 324 |
| 2 | `M22` | contains weak-GP6 witness |
| 3 | `M22` | contains weak-GP6 witness |
| 4 | `PSU(3,5)` | no subgroup weak-GP6 |
| 5 | `3`-local subgroup of order 58320 | no subgroup weak-GP6 |
| 6 | `3^4 : (A6 . C2)` | contains weak-GP6 witness below a subgroup of order 324 |
| 7 | `PSL(3,4) : C2` | contains weak-GP6 witness |
| 8 | `C2 . A8` | contains weak-GP6 witness |
| 9 | `(C2 x C2 x C2 x C2) : A7` | contains weak-GP6 witness |
| 10 | `(C2 x C2 x C2 x C2) : A7` | contains weak-GP6 witness |
| 11 | `M11` | no subgroup weak-GP6 |
| 12 | `5`-local subgroup of order 3000 | no subgroup weak-GP6 |
