#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include "bemenu/bemenu.h"

const char *run_menu(struct bm_menu *menu) {
    uint32_t unicode;
    enum bm_key key;
    enum bm_run_result status = BM_RUN_RESULT_RUNNING;

    bm_menu_set_lines(menu, 5);
    bm_menu_set_filter_mode(menu, BM_FILTER_MODE_DMENU);
    bm_menu_set_title(menu, "waylaunch");
    bm_menu_set_panel_overlap(menu, true);
    bm_menu_grab_keyboard(menu, true);

    do {
        bm_menu_render(menu);
        key = bm_menu_poll_key(menu, &unicode);
    } while ((status = bm_menu_run_with_key(menu, key, unicode)) == BM_RUN_RESULT_RUNNING);

    switch (status) {
    case BM_RUN_RESULT_SELECTED:
        {
            uint32_t count = 0;
            struct bm_item **items = bm_menu_get_selected_items(menu, &count);
            if (count > 0) {
                return bm_item_get_text(items[0]);
            }
        }
        break;
    default:
        break;
    }

    return "";
}

value bmenu_binding(value l) {
    CAMLparam1(l);
    CAMLlocal1(r);

    bm_init();

    struct bm_menu *menu;
    if ((menu = bm_menu_new()) == NULL) {
        r = caml_copy_string("");
        CAMLreturn (r);
    }

    while (l != Val_emptylist) {
        struct bm_item *item = bm_item_new(String_val(Field(l, 0)));
        bm_menu_add_item(menu, item);
        l = Field(l, 1);
    }

    const char *result = run_menu(menu);
    r = caml_copy_string(result);
    bm_menu_free(menu);

    CAMLreturn (r);
}
