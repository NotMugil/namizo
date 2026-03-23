<script lang="ts">
  import { DatePicker as BitsDatePicker } from "bits-ui";
  import { parseDate, type DateValue } from "@internationalized/date";
  import { CalendarBlankIcon, CaretLeftIcon, CaretRightIcon } from "phosphor-svelte";
  import { cn } from "$lib/utils";

  let {
    value = $bindable(""),
    placeholder = "Pick a date",
    disabled = false,
    min = undefined,
    max = undefined,
    triggerClass = "",
    contentClass = "",
  }: {
    value?: string;
    placeholder?: string;
    disabled?: boolean;
    min?: string | undefined;
    max?: string | undefined;
    triggerClass?: string;
    contentClass?: string;
  } = $props();

  let pickerValue = $state<DateValue | undefined>(undefined);

  function safeParseDate(input?: string | null): DateValue | undefined {
    if (!input) return undefined;
    try {
      return parseDate(input);
    } catch {
      return undefined;
    }
  }

  function syncFromExternal() {
    const parsed = safeParseDate(value);
    const current = pickerValue?.toString() ?? "";
    const next = parsed?.toString() ?? "";
    if (current !== next) {
      pickerValue = parsed;
    }
  }

  function handleValueChange(next: DateValue | undefined) {
    pickerValue = next;
    value = next ? next.toString() : "";
  }

  $effect(() => {
    value;
    syncFromExternal();
  });

  const minValue = $derived(safeParseDate(min));
  const maxValue = $derived(safeParseDate(max));
</script>

<BitsDatePicker.Root
  bind:value={pickerValue}
  {disabled}
  {minValue}
  {maxValue}
  onValueChange={handleValueChange}
>
  <BitsDatePicker.Trigger
    class={cn(
      "inline-flex h-9 w-full items-center justify-between gap-2 rounded-[10px] border border-white/15 bg-white/10 px-3 text-sm text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] outline-none transition hover:border-white/22 focus-visible:border-white/26",
      triggerClass
    )}
  >
    <span class={value ? "text-white/90" : "text-white/45"}>{value || placeholder}</span>
    <CalendarBlankIcon size={14} weight="bold" class="text-white/58" />
  </BitsDatePicker.Trigger>

  <BitsDatePicker.Portal>
    <BitsDatePicker.Content
      sideOffset={8}
      class={cn(
        "z-[120] rounded-[12px] border border-white/15 bg-black/88 p-3 text-white shadow-[0_24px_60px_rgba(0,0,0,0.6)] backdrop-blur-[20px]",
        contentClass
      )}
    >
      <BitsDatePicker.Calendar>
        {#snippet children({ months, weekdays })}
          <BitsDatePicker.Header class="mb-3 flex items-center justify-between gap-2">
            <BitsDatePicker.PrevButton
              class="inline-flex size-8 items-center justify-center rounded-md border border-white/15 bg-white/6 text-white/80 transition-colors hover:bg-white/12"
            >
              <CaretLeftIcon size={14} weight="bold" />
            </BitsDatePicker.PrevButton>
            <BitsDatePicker.Heading class="text-sm font-medium text-white/90" />
            <BitsDatePicker.NextButton
              class="inline-flex size-8 items-center justify-center rounded-md border border-white/15 bg-white/6 text-white/80 transition-colors hover:bg-white/12"
            >
              <CaretRightIcon size={14} weight="bold" />
            </BitsDatePicker.NextButton>
          </BitsDatePicker.Header>

          {#each months as month}
            <BitsDatePicker.Grid class="w-full border-collapse select-none">
              <BitsDatePicker.GridHead>
                <BitsDatePicker.GridRow>
                  {#each weekdays as weekday}
                    <BitsDatePicker.HeadCell class="pb-2 text-[0.72rem] font-medium text-white/50">
                      {weekday}
                    </BitsDatePicker.HeadCell>
                  {/each}
                </BitsDatePicker.GridRow>
              </BitsDatePicker.GridHead>
              <BitsDatePicker.GridBody>
                {#each month.weeks as weekDates}
                  <BitsDatePicker.GridRow class="mt-1">
                    {#each weekDates as date}
                      <BitsDatePicker.Cell {date} month={month.value} class="p-0.5">
                        <BitsDatePicker.Day
                          class="inline-flex size-8 items-center justify-center rounded-md text-[0.78rem] text-white/82 outline-none transition-colors hover:bg-white/10 data-[selected]:bg-white data-[selected]:font-medium data-[selected]:text-black data-[disabled]:pointer-events-none data-[disabled]:opacity-30 data-[unavailable]:line-through"
                        >
                          {#snippet children({ day })}
                            {day}
                          {/snippet}
                        </BitsDatePicker.Day>
                      </BitsDatePicker.Cell>
                    {/each}
                  </BitsDatePicker.GridRow>
                {/each}
              </BitsDatePicker.GridBody>
            </BitsDatePicker.Grid>
          {/each}
        {/snippet}
      </BitsDatePicker.Calendar>
    </BitsDatePicker.Content>
  </BitsDatePicker.Portal>
</BitsDatePicker.Root>