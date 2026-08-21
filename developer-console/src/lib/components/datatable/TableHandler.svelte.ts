export type SortDirection = 'asc' | 'desc' | null;

export interface RowCount {
  total: number;
  start: number;
  end: number;
}

export class TableHandler<T = any> {
  rawRows = $state<T[]>([]);
  searchQuery = $state<string>('');
  sortField = $state<string | ((row: T) => any) | null>(null);
  sortDirection = $state<SortDirection>(null);
  currentPage = $state<number>(1);
  rowsPerPage = $state<number>(20);

  constructor(initialData: T[] = [], options: { rowsPerPage?: number } = {}) {
    this.rawRows = initialData;
    if (options.rowsPerPage) {
      this.rowsPerPage = options.rowsPerPage;
    }
  }

  setRows(data: T[]) {
    this.rawRows = data || [];
    this.currentPage = 1;
  }

  setRowsPerPage(value: number) {
    this.rowsPerPage = value;
    this.currentPage = 1;
  }

  setPage(page: number | 'previous' | 'next' | 'last') {
    if (page === 'previous') {
      if (this.currentPage > 1) this.currentPage--;
    } else if (page === 'next') {
      if (this.currentPage < this.pageCount) this.currentPage++;
    } else if (page === 'last') {
      this.currentPage = this.pageCount;
    } else if (typeof page === 'number') {
      if (page >= 1 && page <= this.pageCount) {
        this.currentPage = page;
      }
    }
  }

  // Filtered rows based on global search query
  filteredRows = $derived.by(() => {
    const q = this.searchQuery.trim().toLowerCase();
    if (!q) return this.rawRows;

    return this.rawRows.filter((row: any) => {
      if (!row) return false;
      return Object.values(row).some((val) => {
        if (val === null || val === undefined) return false;
        if (typeof val === 'object') {
          return JSON.stringify(val).toLowerCase().includes(q);
        }
        return String(val).toLowerCase().includes(q);
      });
    });
  });

  // Sorted rows
  sortedRows = $derived.by(() => {
    const field = this.sortField;
    const dir = this.sortDirection;
    if (!field || !dir) return this.filteredRows;

    return [...this.filteredRows].sort((a: any, b: any) => {
      let valA = typeof field === 'function' ? field(a) : a[field];
      let valB = typeof field === 'function' ? field(b) : b[field];

      if (valA === undefined || valA === null) valA = '';
      if (valB === undefined || valB === null) valB = '';

      if (typeof valA === 'number' && typeof valB === 'number') {
        return dir === 'asc' ? valA - valB : valB - valA;
      }

      const strA = String(valA).toLowerCase();
      const strB = String(valB).toLowerCase();

      if (strA < strB) return dir === 'asc' ? -1 : 1;
      if (strA > strB) return dir === 'asc' ? 1 : -1;
      return 0;
    });
  });

  // Paginated rows displayed on current table page
  rows = $derived.by(() => {
    if (!this.rowsPerPage || this.rowsPerPage <= 0) return this.sortedRows;
    const start = (this.currentPage - 1) * this.rowsPerPage;
    return this.sortedRows.slice(start, start + this.rowsPerPage);
  });

  // Row count statistics
  rowCount = $derived.by((): RowCount => {
    const total = this.sortedRows.length;
    if (total === 0) return { total: 0, start: 0, end: 0 };
    const start = (this.currentPage - 1) * this.rowsPerPage + 1;
    const end = Math.min(start + this.rowsPerPage - 1, total);
    return { total, start, end };
  });

  // Total pages
  pageCount = $derived.by(() => {
    if (!this.rowsPerPage || this.rowsPerPage <= 0) return 1;
    return Math.max(1, Math.ceil(this.sortedRows.length / this.rowsPerPage));
  });

  // Pages with ellipsis for pagination bar
  pagesWithEllipsis = $derived.by(() => {
    const total = this.pageCount;
    const current = this.currentPage;
    if (total <= 7) {
      return Array.from({ length: total }, (_, i) => i + 1);
    }

    const pages: (number | null)[] = [];
    if (current <= 4) {
      for (let i = 1; i <= 5; i++) pages.push(i);
      pages.push(null);
      pages.push(total);
    } else if (current >= total - 3) {
      pages.push(1);
      pages.push(null);
      for (let i = total - 4; i <= total; i++) pages.push(i);
    } else {
      pages.push(1);
      pages.push(null);
      pages.push(current - 1);
      pages.push(current);
      pages.push(current + 1);
      pages.push(null);
      pages.push(total);
    }
    return pages;
  });

  createSort(field: string | ((row: T) => any)) {
    const self = this;
    return {
      get isActive() {
        return self.sortField === field;
      },
      get direction() {
        return self.sortField === field ? self.sortDirection : null;
      },
      set() {
        if (self.sortField !== field) {
          self.sortField = field;
          self.sortDirection = 'asc';
        } else if (self.sortDirection === 'asc') {
          self.sortDirection = 'desc';
        } else if (self.sortDirection === 'desc') {
          self.sortField = null;
          self.sortDirection = null;
        } else {
          self.sortDirection = 'asc';
        }
      },
    };
  }

  createSearch() {
    const self = this;
    return {
      get value() {
        return self.searchQuery;
      },
      set value(v: string) {
        self.searchQuery = v;
        self.currentPage = 1;
      },
      set() {
        self.currentPage = 1;
      },
      clear() {
        self.searchQuery = '';
        self.currentPage = 1;
      },
    };
  }

  createCSV() {
    const self = this;
    return {
      download(filename = 'export.csv') {
        const rows = self.sortedRows;
        if (!rows || rows.length === 0) return;

        const headers = Object.keys(rows[0] as any);
        const csvRows = [
          headers.join(','),
          ...rows.map((row: any) =>
            headers
              .map((h) => {
                const val = row[h];
                const str = val === null || val === undefined ? '' : String(val);
                return `"${str.replace(/"/g, '""')}"`;
              })
              .join(',')
          ),
        ];

        const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.setAttribute('href', url);
        link.setAttribute('download', filename);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      },
    };
  }
}
