import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getDashboard from "@salesforce/apex/ChatAnalyticsDashboardController.getDashboard";
import getConversationDetail from "@salesforce/apex/ChatAnalyticsDashboardController.getConversationDetail";
import { refreshApex } from "@salesforce/apex";

export default class ChatAnalyticsDashboard extends NavigationMixin(LightningElement) {
  data; error; wiredResult; selectedDetail; detailError; showDetail = false;
  filters = { analyzedFrom: "", analyzedTo: "", botResolutionStatus: "", escalatedToHuman: "", finalResolutionBy: "" };
  statusOptions = [{ label: "All statuses", value: "" }, { label: "Resolved", value: "Resolved" }, { label: "Partially Resolved", value: "Partially Resolved" }, { label: "Not Resolved", value: "Not Resolved" }, { label: "Indeterminate", value: "Indeterminate" }];
  booleanOptions = [{ label: "All conversations", value: "" }, { label: "Escalated to human", value: "true" }, { label: "Not escalated", value: "false" }];
  finalOptions = [{ label: "All outcomes", value: "" }, { label: "Bot", value: "Bot" }, { label: "Human Agent", value: "Human Agent" }, { label: "Unresolved", value: "Unresolved" }, { label: "Indeterminate", value: "Indeterminate" }];
  @wire(getDashboard, { analyzedFrom: "$filters.analyzedFrom", analyzedTo: "$filters.analyzedTo", botResolutionStatus: "$filters.botResolutionStatus", escalatedToHuman: "$filters.escalatedToHuman", finalResolutionBy: "$filters.finalResolutionBy" })
  wiredDashboard(value) { this.wiredResult = value; if (value.data) { this.data = value.data; this.error = undefined; } else if (value.error) { this.error = value.error; this.data = undefined; } }
  get summary() { return this.data?.summary || {}; }
  get rows() { return this.data?.rows || []; }
  get hasRows() { return this.rows.length > 0; }
  get errorMessage() { return this.error?.body?.message || "Unable to load conversation analytics."; }
  bar(label, count, percent, className) { return { label, count, percent, className, style: `width:${Math.max(0, Math.min(100, percent || 0))}%` }; }
  get statusBars() { const s=this.summary; return [this.bar("Resolved",s.botResolvedCount||0,s.botResolvedPercent||0,"bar good"),this.bar("Partially resolved",s.partiallyResolvedCount||0,s.partiallyResolvedPercent||0,"bar partial"),this.bar("Not resolved",s.botNotResolvedCount||0,s.botNotResolvedPercent||0,"bar not-resolved"),this.bar("Indeterminate",s.indeterminateCount||0,((s.indeterminateCount||0)/(s.totalConversations||1))*100,"bar neutral")]; }
  get escalationBars() { const s=this.summary; return [this.bar("Bot-only / not escalated",(s.totalConversations||0)-(s.escalatedCount||0),100-(s.escalatedPercent||0),"bar blue"),this.bar("Escalated to human",s.escalatedCount||0,s.escalatedPercent||0,"bar orange")]; }
  get finalBars() { const totals={ Bot:0,"Human Agent":0,Unresolved:0,Indeterminate:0 }; this.rows.forEach(r=>{ totals[r.finalResolutionBy] = (totals[r.finalResolutionBy] || 0)+1; }); const n=this.rows.length||1; return Object.keys(totals).map(k=>this.bar(k,totals[k],totals[k]*100/n,"bar purple")); }
  handleFilter(event) { this.filters = { ...this.filters, [event.target.name]: event.detail?.value ?? event.target.value }; }
  async handleRefresh() { await refreshApex(this.wiredResult); }
  async handleDetail(event) { const id=event.currentTarget.dataset.id; try { this.selectedDetail=await getConversationDetail({ conversationRecordId:id }); this.detailError=undefined; this.showDetail=true; } catch(e) { this.detailError=e; } }
  closeDetail() { this.showDetail=false; }
  openRecord() { if(this.selectedDetail?.conversationRecordId) this[NavigationMixin.Navigate]({ type:"standard__recordPage", attributes:{ recordId:this.selectedDetail.conversationRecordId, objectApiName:"Chat_Conversation__c", actionName:"view" } }); }
}