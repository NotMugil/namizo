<script lang="ts">
  import type { Snippet } from "svelte";
  import { Select as BitsSelect } from "bits-ui";
  import { CaretDownIcon, CheckIcon } from "phosphor-svelte";

  export type SelectOption = {
    value: string;
    label: string;
    disabled?: boolean;
  };

  let {
    items = [],
    value = $bindable(""),
    placeholder = "Select",
    disabled = false,
    sideOffset = 6,
    align = "start",
    triggerClass = "",
    contentClass = "",
    prefix,
    onChange,
  }: {
    items?: SelectOption[];
    value?: string;
    placeholder?: string;
    disabled?: boolean;
    sideOffset?: number;
    align?: "start" | "center" | "end";
    triggerClass?: string;
    contentClass?: string;
    prefix?: Snippet;
    onChange?: (value: string) => void;
  } = $props();

  const selectedLabel = $derived(
    items.find((item) => item.value === value)?.label ?? placeholder,
  );

  function handleValueChange(next: string) {
    value = next;
    onChange?.(next);
  }
</script>

<BitsSelect.Root
  type="single"
  bind:value={value as string}
  items={items.map((item) => ({
    value: item.value,
    label: item.label,
    disabled: item.disabled,
  }))}
  onValueChange={(next) => handleValueChange(next)}
  {disabled}
>
  <BitsSelect.Trigger
    class={`inline-flex h-9 min-w-[130px] items-center justify-between gap-2 rounded-[10px] border border-white/12 bg-black/62 px-3 text-sm text-white/86 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] backdrop-blur-[16px] outline-none transition hover:border-white/22 focus-visible:border-white/26 ${triggerClass}`}
  >
    <span class="inline-flex min-w-0 items-center gap-1.5">
      {@render prefix?.()}
      <span class="truncate">{selectedLabel}</span>
    </span>
    <CaretDownIcon size={12} weight="bold" class="shrink-0 text-white/58" />
  </BitsSelect.Trigger>

  <BitsSelect.Portal>
    <BitsSelect.Content
      {sideOffset}
      {align}
      class={`z-[90] min-w-[160px] rounded-[10px] border border-white/14 bg-black/72 p-1 text-white shadow-[0_16px_42px_rgba(0,0,0,0.62)] backdrop-blur-[22px] ${contentClass}`}
    >
      {#each items as item (item.value)}
        <BitsSelect.Item
          value={item.value}
          label={item.label}
          disabled={item.disabled}
          class="flex h-8 items-center justify-between gap-2 rounded-[7px] px-2 text-[0.82rem] text-white/78 outline-none transition hover:bg-white/[0.10] hover:text-white data-[highlighted]:bg-white/[0.10] data-[highlighted]:text-white data-[disabled]:pointer-events-none data-[disabled]:opacity-45"
        >
          {#snippet children({ selected })}
            <span class="truncate">{item.label}</span>
            <CheckIcon
              size={12}
              weight="bold"
              class={selected ? "text-white/90" : "text-transparent"}
            />
          {/snippet}
        </BitsSelect.Item>
      {/each}
    </BitsSelect.Content>
  </BitsSelect.Portal>
</BitsSelect.Root>